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
private final class RenderLog {
    var states: [LoggedOutViewState] = []
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

    private func tree() throws -> RibState { try RibState(decoding: controller.encodedTree) }

    private func child(_ state: RibState?) -> RibState? { state?["child"]?.stateValue }

    private func send(_ screen: RibState?, _ action: String, _ argument: String = "") throws {
        let id = try #require(screen?["id"]?.intValue)
        #expect(controller.dispatch(screenID: id, action: action, argument: argument))
    }

    /// 지금 떠 있는 LoggedOut 화면에 붙어, 받은 상태를 순서대로 모은다.
    private func attachLoggedOut() throws -> (screen: LoggedOutScreen, rendered: RenderLog) {
        let id = try #require(child(try tree())?["id"]?.intValue)
        let screen = try #require(controller.loggedOutScreen(id: id))
        let rendered = RenderLog()
        screen.attach { rendered.states.append($0) }
        return (screen, rendered)
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

    @Test func loggedOutStateStaysOutOfTree() throws {
        controller.start(savedState: nil)
        let loggedOut = child(try tree())
        #expect(loggedOut?["error"] == nil)
        #expect(loggedOut?["loading"] == nil)
    }

    @Test func loggedOutScreenLookupRejectsOtherScreens() throws {
        controller.start(savedState: nil)
        let rootID = try #require(try tree()["id"]?.intValue)
        #expect(controller.loggedOutScreen(id: rootID) == nil)
        #expect(controller.loggedOutScreen(id: -1) == nil)
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
        let loggedIn = child(try tree())
        #expect(loggedIn?["kind"] == .string(ScreenKind.loggedIn))
        #expect(loggedIn?["userName"] == .string("carti"))
        #expect(child(loggedIn)?["kind"] == .string(ScreenKind.todoList))

        try send(loggedIn, ScreenAction.logout)
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
        try attachLoggedOut().screen.send(.loginTapped(rawName: "carti"))
        await settle()
        await clock.advance()
        try send(child(child(try tree())), ScreenAction.selectTodo, "1")

        let detail = child(child(try tree()))
        #expect(detail?["kind"] == .string(ScreenKind.todoDetail))
        #expect(detail?["title"] == .string("우유 사기"))
        try send(detail, ScreenAction.toggleDone)
        #expect(child(child(try tree()))?["isDone"] == .bool(true))

        #expect(controller.handleBackPress())
        await settle()
        let list = child(child(try tree()))
        #expect(list?["kind"] == .string(ScreenKind.todoList))
        #expect(list?["todos"]?.listValue?.first?.stateValue?["isDone"] == .bool(true))
        #expect(!controller.handleBackPress())
    }

    @Test func savedStateRestoresLoggedInUser() async throws {
        controller.start(savedState: nil)
        try attachLoggedOut().screen.send(.loginTapped(rawName: "carti"))
        await settle()
        await clock.advance()
        let saved = controller.saveState()
        controller.stop()

        let restored = AndroidLoginController(authService: DelayedAuthService(delay: .zero, clock: clock), clock: clock, sink: { _ in })
        #expect(restored.start(savedState: saved))
        #expect(child(try RibState(decoding: restored.encodedTree))?["userName"] == .string("carti"))
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
