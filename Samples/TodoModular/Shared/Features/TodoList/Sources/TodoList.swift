import FeatureTodoListInterface
import RIBs
import TodoCore

public final class TodoListBuilder: Builder<any TodoListDependency>, TodoListBuildable {
    private let viewFactory: any TodoListViewFactory

    public init(dependency: any TodoListDependency, viewFactory: any TodoListViewFactory) {
        self.viewFactory = viewFactory
        super.init(dependency: dependency)
    }

    public func build(listener: any TodoListListener) -> any ViewableRouting {
        let view = viewFactory.makeTodoListView()
        let interactor = TodoListInteractor(presenter: view, todoStore: dependency.todoStore, listener: listener)
        return ViewableRouter<TodoListInteractor, any TodoListViewControllable>(
            interactor: interactor, viewController: view
        )
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
                presenter.render(TodoListViewState(todos: todos))
            }
        }
    }

    override func willResignActive() {
        presenter.listener = nil
    }

    func handle(_ action: TodoListViewAction) {
        switch action {
        case .todoTapped(let id): listener?.didSelectTodo(id: id)
        }
    }
}
