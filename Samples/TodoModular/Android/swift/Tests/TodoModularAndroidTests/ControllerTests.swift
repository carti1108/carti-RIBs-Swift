import FeatureLoggedInAndroid
import FeatureLoggedOutAndroid
import FeatureTodoDetailAndroid
import FeatureTodoListAndroid
import RIBs
import Testing
import TodoAndroidSupport
import TodoCore
import TodoCoreTesting
import TodoModularAndroid

/// 화면 트리(JSON)에서 노드를 읽는 도우미.
@MainActor
private func tree(_ controller: some RibController) throws -> RibState {
    try RibState(decoding: controller.encodedTree)
}

private func child(_ state: RibState?) -> RibState? { state?["child"]?.stateValue }
private func kind(_ state: RibState?) -> String? { state?["kind"]?.stringValue }
private func id(_ state: RibState?) throws -> Int64 { try #require(state?["id"]?.intValue) }

@MainActor
struct TodoAppControllerTests {
    private let auth = FakeAuthService()
    private let controller: TodoAppController

    init() {
        controller = TodoAppController(authService: auth, clock: ManualClock(), sink: { _ in })
    }

    @Test func startsAtLoggedOutScreen() throws {
        #expect(controller.start(savedState: nil) == false)

        #expect(kind(child(try tree(controller))) == LoggedOutAndroidViewFactory.kind)
        controller.stop()
    }

    @Test func loginShowsLoggedInWithTodoList() async throws {
        controller.start(savedState: nil)
        let loggedOut = try #require(controller.screen(id: try id(child(try tree(controller))), as: LoggedOutAndroidScreen.self))

        loggedOut.send(.loginTapped(rawName: " carti "))
        await runCurrent()
        #expect(loggedOut.currentState.isLoading)
        auth.respond(.success(userName: "carti"))
        await runCurrent()

        let loggedInNode = child(try tree(controller))
        #expect(kind(loggedInNode) == LoggedInAndroidViewFactory.kind)
        let loggedIn = try #require(controller.screen(id: try id(loggedInNode), as: LoggedInAndroidScreen.self))
        #expect(loggedIn.currentState.userName == "carti")
        #expect(kind(child(loggedInNode)) == TodoListAndroidViewFactory.kind)
        controller.stop()
    }

    @Test func restoresOpenDetailFromSavedState() async throws {
        controller.start(savedState: nil)
        let loggedOut = try #require(controller.screen(id: try id(child(try tree(controller))), as: LoggedOutAndroidScreen.self))
        loggedOut.send(.loginTapped(rawName: "carti"))
        await runCurrent()
        auth.respond(.success(userName: "carti"))
        await runCurrent()
        let listNode = child(child(try tree(controller)))
        try #require(controller.screen(id: try id(listNode), as: TodoListAndroidScreen.self)).send(.todoTapped(id: 2))
        let saved = try #require(controller.saveState())
        controller.stop()

        let restored = TodoAppController(authService: FakeAuthService(), clock: ManualClock(), sink: { _ in })
        #expect(restored.start(savedState: saved))
        let detailNode = child(child(try tree(restored)))
        #expect(kind(detailNode) == TodoDetailAndroidViewFactory.kind)
        let detail = try #require(restored.screen(id: try id(detailNode), as: TodoDetailAndroidScreen.self))
        #expect(detail.currentState.title == "RIB 문서 읽기")
        restored.stop()
    }
}

@MainActor
struct FeatureDemoControllerTests {
    private func makeDemo(_ feature: DemoFeature) -> FeatureDemoController {
        FeatureDemoController(feature: feature, authService: FakeAuthService(), clock: ManualClock(), sink: { _ in })
    }

    @Test(arguments: [
        (DemoFeature.loggedOut, LoggedOutAndroidViewFactory.kind),
        (.loggedIn, LoggedInAndroidViewFactory.kind),
        (.todoList, TodoListAndroidViewFactory.kind),
        (.todoDetail, TodoDetailAndroidViewFactory.kind),
    ])
    func showsOnlyTheChosenFeature(feature: DemoFeature, expectedKind: String) throws {
        let demo = makeDemo(feature)

        #expect(demo.start(savedState: nil) == false)

        let root = try tree(demo)
        #expect(kind(root) == HostScreenKind.root)
        #expect(kind(child(root)) == expectedKind)
        #expect(demo.saveState() == nil)
        demo.stop()
    }

    @Test func loggedInDemoUsesPlaceholderChildrenAndRoutesToDetail() throws {
        let demo = makeDemo(.loggedIn)
        demo.start(savedState: nil)
        let listNode = child(child(try tree(demo)))
        #expect(kind(listNode) == HostScreenKind.placeholder)

        try #require(demo.screen(id: try id(listNode), as: PlaceholderScreen.self)).tapAction()

        let detailNode = child(child(try tree(demo)))
        let detail = try #require(demo.screen(id: try id(detailNode), as: PlaceholderScreen.self))
        #expect(detail.currentState.title == "자리표시 상세 #1")
        #expect(demo.handleBackPress())
        #expect(kind(child(child(try tree(demo)))) == HostScreenKind.placeholder)
        demo.stop()
    }

    @Test func todoListDemoShowsParentEventAndTogglesSelectedTodo() async throws {
        let demo = makeDemo(.todoList)
        demo.start(savedState: nil)
        await runCurrent()
        let listNode = child(try tree(demo))
        let list = try #require(demo.screen(id: try id(listNode), as: TodoListAndroidScreen.self))

        list.send(.todoTapped(id: 1))
        await runCurrent()

        #expect(try tree(demo)["event"]?.stringValue == "didSelectTodo(id: 1)")
        #expect(list.currentState.todos.first?.isDone == true)
        demo.stop()
    }
}
