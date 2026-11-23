import FeatureTodoListInterface
import FeatureTodoListTesting
import RIBs
import Testing
import TodoCore
import TodoCoreTesting

@testable import FeatureTodoList

@MainActor
final class TodoListTests {
    private let store = TodoStore()
    private let views = FakeTodoListViewFactory()
    private let listener = FakeTodoListListener()
    private let parent = TestParentRouter()
    private let router: any ViewableRouting

    init() async {
        let builder = TodoListBuilder(dependency: FakeTodoListDependency(todoStore: store), viewFactory: views)
        router = builder.build(listener: listener)
        parent.attach(router)
        await runCurrent()
    }

    isolated deinit {
        parent.detach(router)
    }

    private var view: FakeTodoListView { views.views.last! }

    @Test func showsTodosFromStore() {
        #expect(view.todos == TodoStore.sampleTodos)
    }

    @Test func reflectsStoreChanges() async {
        store.toggle(3)
        await runCurrent()

        #expect(view.todos.filter(\.isDone).map(\.id) == [3])
    }

    @Test func tapTellsListener() {
        view.listener?.didTapTodo(id: 2)

        #expect(listener.selectedIDs == [2])
    }
}
