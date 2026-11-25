import AndroidLoginUI
import LoginShared
import RIBs
import Testing

/// 시간을 테스트가 직접 넘기는 시계. `advance()`가 기다리는 쪽을 모두 깨운다.
@MainActor
private final class ManualClock: LoginClock {
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func sleep(for duration: Duration) async throws(CancellationError) {
        await withCheckedContinuation { waiters.append($0) }
        if Task.isCancelled { throw CancellationError() }
    }

    func advance() async {
        let current = waiters
        waiters = []
        current.forEach { $0.resume() }
        await settle()
    }

    var hasWaiters: Bool { !waiters.isEmpty }
}

/// 화면이 그리라고 넘긴 상태 기록.
@MainActor
private final class RenderLog<State> {
    var states: [State] = []
}

@MainActor
private func settle() async {
    for _ in 0..<20 { await Task.yield() }
}

@MainActor
struct AndroidLoginControllerTests {
    private let clock = ManualClock()
    private let controller: AndroidLoginController

    init() {
        let clock = self.clock
        controller = AndroidLoginController(
            authService: DelayedAuthService(delay: .seconds(1), clock: clock),
            clock: clock,
            sink: { _ in }
        )
    }

    private func tree(_ controller: AndroidLoginController? = nil) throws -> RibState {
        try RibState(decoding: (controller ?? self.controller).encodedTree)
    }

    private func child(_ state: RibState?) -> RibState? { state?["child"]?.stateValue }

    /// 화면 트리 노드의 `id`로 화면을 찾아 붙고, 받은 상태를 순서대로 모은다.
    private func attach<State, Screen: BridgedScreen<State>>(
        _ node: RibState?,
        as type: Screen.Type,
        in controller: AndroidLoginController? = nil
    ) throws -> (screen: Screen, rendered: RenderLog<State>) {
        let id = try #require(node?["id"]?.intValue)
        let screen = try #require((controller ?? self.controller).screen(id: id, as: type))
        let rendered = RenderLog<State>()
        screen.attach { rendered.states.append($0) }
        return (screen, rendered)
    }

    private func attachLoggedOut() throws -> (screen: LoggedOutScreen, rendered: RenderLog<LoggedOutViewState>) {
        try attach(child(try tree()), as: LoggedOutScreen.self)
    }

    private func logIn(_ name: String = "carti") async throws {
        try attachLoggedOut().screen.send(.loginTapped(rawName: name))
        await settle()
        await clock.advance()
    }

    @Test func startsOnLoggedOutScreen() throws {
        controller.start(savedState: nil)
        #expect(child(try tree())?["kind"] == .string(ScreenKind.loggedOut))
    }

    @Test func attachReplaysCurrentLoggedOutState() throws {
        controller.start(savedState: nil)
        let (_, rendered) = try attachLoggedOut()
        #expect(rendered.states == [LoggedOutViewState()])
    }

    @Test func screenStateStaysOutOfTree() async throws {
        controller.start(savedState: nil)
        let loggedOut = child(try tree())
        #expect(loggedOut?["error"] == nil)
        #expect(loggedOut?["loading"] == nil)

        try await logIn()
        let loggedIn = child(try tree())
        #expect(loggedIn?["userName"] == nil)
        #expect(loggedIn?["sessionSeconds"] == nil)
        #expect(child(loggedIn)?["todos"] == nil)
    }

    @Test func screenLookupRejectsOtherScreens() throws {
        controller.start(savedState: nil)
        let rootID = try #require(try tree()["id"]?.intValue)
        let loggedOutID = try #require(child(try tree())?["id"]?.intValue)
        #expect(controller.screen(id: rootID, as: LoggedOutScreen.self) == nil)
        #expect(controller.screen(id: -1, as: LoggedOutScreen.self) == nil)
        #expect(controller.screen(id: loggedOutID, as: LoggedInScreen.self) == nil)
    }

    @Test func blankNameShowsError() throws {
        controller.start(savedState: nil)
        let (screen, rendered) = try attachLoggedOut()
        screen.send(.loginTapped(rawName: "   "))
        #expect(rendered.states.last == LoggedOutViewState(errorMessage: "이름을 입력하세요", isLoading: false))
    }

    @Test func detachStopsRendering() throws {
        controller.start(savedState: nil)
        let (screen, rendered) = try attachLoggedOut()
        screen.detach()
        screen.send(.loginTapped(rawName: "   "))
        #expect(rendered.states.count == 1)
    }

    @Test func loginShowsLoadingThenLoggedInAndLogoutReturns() async throws {
        controller.start(savedState: nil)
        let (screen, rendered) = try attachLoggedOut()
        screen.send(.loginTapped(rawName: " carti "))
        await settle()
        #expect(rendered.states.last == LoggedOutViewState(errorMessage: nil, isLoading: true))

        await clock.advance()
        let loggedInNode = child(try tree())
        #expect(loggedInNode?["kind"] == .string(ScreenKind.loggedIn))
        #expect(child(loggedInNode)?["kind"] == .string(ScreenKind.todoList))
        let loggedIn = try attach(loggedInNode, as: LoggedInScreen.self)
        #expect(loggedIn.rendered.states.last?.userName == "carti")

        loggedIn.screen.tapLogout()
        #expect(child(try tree())?["kind"] == .string(ScreenKind.loggedOut))
        #expect(try attachLoggedOut().rendered.states == [LoggedOutViewState()])
    }

    @Test func failingNameShowsServerError() async throws {
        controller.start(savedState: nil)
        let (screen, rendered) = try attachLoggedOut()
        screen.send(.loginTapped(rawName: "fail"))
        await settle()
        await clock.advance()
        #expect(rendered.states.last == LoggedOutViewState(errorMessage: "로그인에 실패했습니다", isLoading: false))
    }

    @Test func detailToggleAndBackPress() async throws {
        controller.start(savedState: nil)
        try await logIn()
        let list = try attach(child(child(try tree())), as: TodoListScreen.self)
        #expect(list.rendered.states.last?.first == Todo(id: 1, title: "우유 사기", isDone: false))
        list.screen.tapTodo(id: 1)

        let detailNode = child(child(try tree()))
        #expect(detailNode?["kind"] == .string(ScreenKind.todoDetail))
        let detail = try attach(detailNode, as: TodoDetailScreen.self)
        #expect(detail.rendered.states.last == TodoDetailScreenState(title: "우유 사기", isDone: false))
        detail.screen.tapToggleDone()
        #expect(detail.rendered.states.last?.isDone == true)

        #expect(controller.handleBackPress())
        await settle()
        let listNode = child(child(try tree()))
        #expect(listNode?["kind"] == .string(ScreenKind.todoList))
        #expect(try attach(listNode, as: TodoListScreen.self).rendered.states.last?.first?.isDone == true)
        #expect(!controller.handleBackPress())
    }

    @Test func detailBackTapReturnsToList() async throws {
        controller.start(savedState: nil)
        try await logIn()
        try attach(child(child(try tree())), as: TodoListScreen.self).screen.tapTodo(id: 1)
        try attach(child(child(try tree())), as: TodoDetailScreen.self).screen.tapBack()
        await settle()
        #expect(child(child(try tree()))?["kind"] == .string(ScreenKind.todoList))
    }

    @Test func savedStateRestoresLoggedInUser() async throws {
        controller.start(savedState: nil)
        try await logIn()
        let saved = controller.saveState()
        controller.stop()

        let restored = AndroidLoginController(authService: DelayedAuthService(delay: .zero, clock: clock), clock: clock, sink: { _ in })
        #expect(restored.start(savedState: saved))
        let loggedIn = try attach(child(try tree(restored)), as: LoggedInScreen.self, in: restored)
        #expect(loggedIn.rendered.states.last?.userName == "carti")
        restored.stop()
    }

    @Test func corruptSavedStateFallsBackToFreshStart() throws {
        #expect(!controller.start(savedState: "{broken"))
        #expect(child(try tree())?["kind"] == .string(ScreenKind.loggedOut))
    }

    @Test func stopClearsTree() {
        controller.start(savedState: nil)
        controller.stop()
        #expect(controller.encodedTree == "{}")
    }
}
