import RIBs

@MainActor
public protocol TodoListPresentableListener: AnyObject {
    func didTapTodo(id: Int64)
}

@MainActor
public protocol TodoListPresentable: Presentable {
    var listener: (any TodoListPresentableListener)? { get set }
    func showTodos(_ todos: [Todo])
}

@MainActor
public protocol TodoListViewControllable: ViewControllable {}

@MainActor
public protocol TodoListViewContract: TodoListPresentable, TodoListViewControllable {}

@MainActor
protocol TodoListDependency: Dependency {
    var viewFactory: any LoginViewFactory { get }
    var todoStore: TodoStore { get }
}

@MainActor
protocol TodoListListener: AnyObject {
    func didSelectTodo(id: Int64)
}

final class TodoListBuilder: Builder<any TodoListDependency> {
    func build(listener: any TodoListListener) -> TodoListRouter {
        let view = dependency.viewFactory.makeTodoListView()
        let interactor = TodoListInteractor(presenter: view, todoStore: dependency.todoStore, listener: listener)
        return TodoListRouter(interactor: interactor, viewController: view)
    }
}

/// 저장소의 목록을 구독해 뷰를 갱신한다. 구독은 활성 구간에서만 돈다.
final class TodoListInteractor: PresentableInteractor<any TodoListPresentable>, TodoListPresentableListener {
    private let todoStore: TodoStore
    private weak var listener: (any TodoListListener)?

    init(presenter: any TodoListPresentable, todoStore: TodoStore, listener: any TodoListListener) {
        self.todoStore = todoStore
        self.listener = listener
        super.init(presenter: presenter)
    }

    override func didBecomeActive() {
        presenter.listener = self
        let updates = todoStore.updates
        startTask { [presenter] in
            for await todos in updates {
                presenter.showTodos(todos)
            }
        }
    }

    override func willResignActive() {
        presenter.listener = nil
    }

    func didTapTodo(id: Int64) { listener?.didSelectTodo(id: id) }
}

typealias TodoListRouter = ViewableRouter<TodoListInteractor, any TodoListViewControllable>
