import FeatureTodoDetailInterface
import FeatureTodoDetailTesting
import RIBs
import Testing
import TodoCore
import TodoCoreTesting

@testable import FeatureTodoDetail

@MainActor
final class TodoDetailTests {
    private let store = TodoStore()
    private let views = FakeTodoDetailViewFactory()
    private let listener = FakeTodoDetailListener()
    private let parent = TestParentRouter()
    private let builder: TodoDetailBuilder

    init() {
        builder = TodoDetailBuilder(dependency: FakeTodoDetailDependency(todoStore: store), viewFactory: views)
    }

    private func open(_ id: Int64) throws -> any TodoDetailRouting {
        let router = try #require(builder.build(listener: listener, todoID: id))
        parent.attach(router)
        return router
    }

    @Test func missingTodoBuildsNothing() {
        #expect(builder.build(listener: listener, todoID: 99) == nil)
        #expect(views.views.isEmpty)
    }

    @Test func showsTodoAndRemembersID() throws {
        let router = try open(2)

        #expect(router.todoID == 2)
        #expect(views.views.last?.states == [TodoDetailViewState(title: "RIB 문서 읽기", isDone: false)])
        parent.detach(router)
    }

    @Test func toggleUpdatesStoreAndView() throws {
        let router = try open(1)

        views.views.last?.listener?.handle(.toggleDoneTapped)

        #expect(store.doneIDs == [1])
        #expect(views.views.last?.state?.isDone == true)
        parent.detach(router)
    }

    @Test func backTellsListener() throws {
        let router = try open(1)

        views.views.last?.listener?.handle(.backTapped)

        #expect(listener.closeRequests == 1)
        parent.detach(router)
    }
}
