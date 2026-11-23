import FeatureLoggedInInterface
import FeatureLoggedInTesting
import FeatureLoggedOutInterface
import FeatureLoggedOutTesting
import FeatureTodoDetailInterface
import FeatureTodoDetailTesting
import FeatureTodoListInterface
import FeatureTodoListTesting
import RIBs
import Testing
import TodoAppRoot
import TodoCore
import TodoCoreTesting

@MainActor
final class FakeRootView: RootViewControllable {
    var screen: (any ViewControllable)?
    func showScreen(_ screen: any ViewControllable) { self.screen = screen }
    func hideScreen(_ screen: any ViewControllable) { if self.screen === screen { self.screen = nil } }
}

/// 피처별 가짜 팩토리를 묶어 앱 전체 팩토리로 쓴다.
@MainActor
final class FakeAppViewFactory: TodoAppViewFactory {
    let root = FakeRootView()
    let loggedOut = FakeLoggedOutViewFactory()
    let loggedIn = FakeLoggedInViewFactory()
    let todoList = FakeTodoListViewFactory()
    let todoDetail = FakeTodoDetailViewFactory()

    func makeRootView() -> FakeRootView { root }
    func makeLoggedOutView() -> any LoggedOutViewContract { loggedOut.makeLoggedOutView() }
    func makeLoggedInView() -> any LoggedInViewContract { loggedIn.makeLoggedInView() }
    func makeTodoListView() -> any TodoListViewContract { todoList.makeTodoListView() }
    func makeTodoDetailView() -> any TodoDetailViewContract { todoDetail.makeTodoDetailView() }
}

@MainActor
final class FakeHost: ViewHost {
    var shown: FakeRootView?
    var hidden = false
    func show(_ view: FakeRootView) { shown = view }
    func hide(_ view: FakeRootView) { hidden = true }
}

/// 실제 피처 Impl을 모두 이은 통합 테스트. `LoginShared`의 `LoginAppTests`와 같은 흐름이다.
@MainActor
final class TodoAppTests {
    private let factory = FakeAppViewFactory()
    private let host = FakeHost()
    private let auth = FakeAuthService()
    private let clock = ManualClock()
    private let app: TodoApp<FakeAppViewFactory>

    init() {
        app = TodoApp(viewFactory: factory, authService: auth, clock: clock)
    }

    isolated deinit {
        app.stop()
    }

    private var loggedOut: FakeLoggedOutView { factory.loggedOut.views.last! }

    private func startLoggedIn() async throws {
        try app.start(host: host)
        loggedOut.listener?.handle(.loginTapped(rawName: "carti"))
        await runCurrent()
        auth.respond(.success(userName: "carti"))
        await runCurrent()
    }

    @Test func startShowsLoggedOut() throws {
        try app.start(host: host)

        #expect(host.shown === factory.root)
        #expect(factory.root.screen === loggedOut)
    }

    @Test func loginShowsLoggedInWithList() async throws {
        try await startLoggedIn()

        let loggedIn = try #require(factory.loggedIn.views.last)
        #expect(factory.root.screen === loggedIn)
        #expect(loggedIn.state?.userName == "carti")
        #expect(loggedIn.screen === factory.todoList.views.last)
        #expect(factory.todoList.views.last?.state?.todos == TodoStore.sampleTodos)
    }

    @Test func detailToggleReachesListAndBackPopsDetail() async throws {
        try await startLoggedIn()
        factory.todoList.views.last?.listener?.handle(.todoTapped(id: 1))

        factory.todoDetail.views.last?.listener?.handle(.toggleDoneTapped)
        await runCurrent()
        #expect(factory.todoList.views.last?.state?.todos.filter(\.isDone).map(\.id) == [1])

        #expect(app.handleBackPress())
        #expect(factory.loggedIn.views.last?.screen === factory.todoList.views.last)
        #expect(!app.handleBackPress())
    }

    @Test func logoutReturnsToFreshLoggedOut() async throws {
        try await startLoggedIn()

        factory.loggedIn.views.last?.listener?.handle(.logoutTapped)

        #expect(factory.loggedOut.views.count == 2)
        #expect(factory.root.screen === loggedOut)
    }

    @Test func backOnLoggedOutIsNotHandled() throws {
        try app.start(host: host)

        #expect(!app.handleBackPress())
    }

    @Test func savedStateRestoresUserOpenDetailAndDoneTodos() async throws {
        try await startLoggedIn()
        factory.todoList.views.last?.listener?.handle(.todoTapped(id: 3))
        factory.todoDetail.views.last?.listener?.handle(.toggleDoneTapped)
        let saved = app.saveState()
        app.stop()

        let restoredFactory = FakeAppViewFactory()
        let restored = TodoApp(viewFactory: restoredFactory, authService: FakeAuthService(), clock: ManualClock())
        try restored.start(host: FakeHost(), savedState: saved)
        await runCurrent()

        #expect(restoredFactory.loggedOut.views.isEmpty)
        #expect(restoredFactory.loggedIn.views.last?.state?.userName == "carti")
        #expect(restoredFactory.loggedIn.views.last?.screen === restoredFactory.todoDetail.views.last)
        #expect(restoredFactory.todoDetail.views.last?.state?.title == "운동하기")
        #expect(restoredFactory.todoDetail.views.last?.state?.isDone == true)
        restored.stop()
    }

    @Test func corruptSavedStateIsRejectedWithoutStarting() {
        #expect(throws: RibStateDecodingError.self) {
            try app.start(host: host, savedState: "{not json")
        }
        #expect(host.shown == nil)
    }
}
