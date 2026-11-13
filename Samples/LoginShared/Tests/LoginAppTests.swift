import RIBs
import Testing
@testable import LoginShared

/// carti-RIBs-KMP `LoginAppTest` 이식. 시계와 인증 서비스를 가짜로 넣어 실제로 기다리지 않는다.
@MainActor
final class LoginAppTests {
    private let factory = FakeViewFactory()
    private let host = FakeHost()
    private let auth = FakeAuthService()
    private let clock = ManualClock()
    private let app: LoginApp<FakeViewFactory>

    init() {
        app = LoginApp(viewFactory: factory, authService: auth, clock: clock)
    }

    /// 세션 타이머 같은 끝없는 Task가 다음 테스트로 새지 않도록 트리를 내린다(KMP `@AfterTest`).
    isolated deinit {
        app.stop()
    }

    private var loggedOut: FakeLoggedOutView { factory.loggedOut.last! }

    private func login(_ name: String) async {
        loggedOut.listener?.didTapLogin(rawName: name)
        await runCurrent()
    }

    private func startLoggedIn() async throws {
        try app.start(host: host)
        await login("carti")
        auth.respond(.success(userName: "carti"))
        await runCurrent()
    }

    @Test func startShowsRootWithLoggedOutScreen() throws {
        try app.start(host: host)

        #expect(host.shown === factory.root)
        #expect(factory.root.screen === loggedOut)
    }

    @Test func blankNameShowsErrorWithoutCallingService() async throws {
        try app.start(host: host)

        await login("   ")

        #expect(loggedOut.error == LoggedOutInteractor.emptyNameError)
        #expect(auth.requests.isEmpty)
    }

    @Test func loginShowsLoadingUntilServiceResponds() async throws {
        try app.start(host: host)

        await login("  carti ")

        #expect(auth.requests == ["carti"])
        #expect(loggedOut.isLoading)
        #expect(factory.root.screen === loggedOut)
    }

    @Test func successfulLoginSwitchesToLoggedIn() async throws {
        try app.start(host: host)
        await login("carti")

        auth.respond(.success(userName: "carti"))
        await runCurrent()

        #expect(factory.root.screen === factory.loggedIn.last)
        #expect(factory.loggedIn.last?.userName == "carti")
    }

    @Test func failedLoginShowsErrorAndStopsLoading() async throws {
        try app.start(host: host)
        await login("carti")

        auth.respond(.failure(message: "서버 오류"))
        await runCurrent()

        #expect(loggedOut.error == "서버 오류")
        #expect(!loggedOut.isLoading)
        #expect(factory.root.screen === loggedOut)
    }

    @Test func tapWhileLoadingIsIgnored() async throws {
        try app.start(host: host)
        await login("carti")

        await login("other")

        #expect(auth.requests == ["carti"])
    }

    @Test func stopWhileLoadingCancelsRequest() async throws {
        try app.start(host: host)
        await login("carti")

        app.stop()
        await runCurrent()

        #expect(auth.wasCancelled)
        #expect(host.hidden)
    }

    @Test func logoutReturnsToFreshLoggedOutScreen() async throws {
        try await startLoggedIn()
        let loggedIn = try #require(factory.loggedIn.last)

        loggedIn.listener?.didTapLogout()

        #expect(factory.loggedOut.count == 2)
        #expect(factory.root.screen === loggedOut)
        #expect(!loggedOut.isLoading)
        #expect(loggedIn.listener == nil)
    }

    @Test func loggedInShowsTodoListByDefault() async throws {
        try await startLoggedIn()

        #expect(factory.loggedIn.last?.screen === factory.todoLists.last)
        #expect(factory.todoLists.last?.todos == TodoStore.sampleTodos)
    }

    @Test func selectingTodoPushesDetailAndBackPopsIt() async throws {
        try await startLoggedIn()

        factory.todoLists.last?.listener?.didTapTodo(id: 2)
        #expect(factory.loggedIn.last?.screen === factory.todoDetails.last)
        #expect(factory.todoDetails.last?.title == "RIB 문서 읽기")

        #expect(app.handleBackPress())
        #expect(factory.loggedIn.last?.screen === factory.todoLists.last)
        #expect(factory.todoDetails.last?.listener == nil)

        #expect(!app.handleBackPress())
    }

    @Test func backOnLoggedOutScreenIsNotHandled() throws {
        try app.start(host: host)

        #expect(!app.handleBackPress())
    }

    @Test func togglingDoneInDetailUpdatesListThroughSharedStore() async throws {
        try await startLoggedIn()
        factory.todoLists.last?.listener?.didTapTodo(id: 1)

        factory.todoDetails.last?.listener?.didTapToggleDone()
        factory.todoDetails.last?.listener?.didTapBack()
        await runCurrent()

        #expect(factory.todoDetails.last?.isDone == true)
        #expect(factory.todoLists.last?.todos.filter(\.isDone).map(\.id) == [1])
        #expect(factory.loggedIn.last?.screen === factory.todoLists.last)
    }

    @Test func sessionTimerTicksWhileLoggedInAndStopsAfterLogout() async throws {
        try await startLoggedIn()
        let view = try #require(factory.loggedIn.last)
        #expect(view.sessionSeconds == 0)

        await clock.advance(by: .milliseconds(2_500))
        #expect(view.sessionSeconds == 2)

        view.listener?.didTapLogout()
        await runCurrent()
        await clock.advance(by: .seconds(5))
        #expect(view.sessionSeconds == 2)
    }

    @Test func savedStateRestoresUserOpenDetailAndDoneTodos() async throws {
        try await startLoggedIn()
        factory.todoLists.last?.listener?.didTapTodo(id: 3)
        factory.todoDetails.last?.listener?.didTapToggleDone()
        let saved = app.saveState()
        app.stop()

        let restoredFactory = FakeViewFactory()
        let restored = LoginApp(viewFactory: restoredFactory, authService: FakeAuthService(), clock: ManualClock())
        try restored.start(host: FakeHost(), savedState: saved)
        await runCurrent()

        #expect(restoredFactory.loggedOut.isEmpty)
        #expect(restoredFactory.loggedIn.last?.userName == "carti")
        #expect(restoredFactory.loggedIn.last?.screen === restoredFactory.todoDetails.last)
        #expect(restoredFactory.todoDetails.last?.title == "운동하기")
        #expect(restoredFactory.todoDetails.last?.isDone == true)
        restored.stop()
    }

    @Test func corruptSavedStateIsRejectedWithoutStarting() {
        #expect(throws: RibStateDecodingError.self) {
            try app.start(host: host, savedState: "{not json")
        }
        #expect(host.shown == nil)
    }

    @Test func delayedAuthServiceFailsOnlyForFailingName() async throws {
        let clock = ManualClock()
        let service = DelayedAuthService(delay: .milliseconds(800), clock: clock)
        var results: [AuthResult] = []

        let task = Task {
            results.append(try await service.signIn(userName: "carti"))
            results.append(try await service.signIn(userName: DelayedAuthService.failingName))
        }
        await runCurrent()
        #expect(results.isEmpty)
        await clock.advance(by: .milliseconds(1_600))
        try await task.value

        #expect(results == [.success(userName: "carti"), .failure(message: DelayedAuthService.failureMessage)])
    }
}
