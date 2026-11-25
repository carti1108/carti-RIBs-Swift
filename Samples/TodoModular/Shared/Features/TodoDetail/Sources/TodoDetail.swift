import FeatureTodoDetailInterface
import RIBs
import TodoCore

public final class TodoDetailBuilder: Builder<any TodoDetailDependency>, TodoDetailBuildable {
    private let viewFactory: any TodoDetailViewFactory

    public init(dependency: any TodoDetailDependency, viewFactory: any TodoDetailViewFactory) {
        self.viewFactory = viewFactory
        super.init(dependency: dependency)
    }

    public func build(listener: any TodoDetailListener, todoID: Int64) -> (any TodoDetailRouting)? {
        guard dependency.todoStore.find(todoID) != nil else { return nil }
        let view = viewFactory.makeTodoDetailView()
        let interactor = TodoDetailInteractor(
            presenter: view, todoID: todoID, todoStore: dependency.todoStore, listener: listener
        )
        return TodoDetailRouter(interactor: interactor, viewController: view, todoID: todoID)
    }
}

/// 완료 표시를 바꾸면 저장소를 거쳐 목록에도 반영된다.
final class TodoDetailInteractor: PresentableInteractor<any TodoDetailPresentable>, TodoDetailPresentableListener {
    private let todoID: Int64
    private let todoStore: TodoStore
    private weak var listener: (any TodoDetailListener)?

    init(presenter: any TodoDetailPresentable, todoID: Int64, todoStore: TodoStore, listener: any TodoDetailListener) {
        self.todoID = todoID
        self.todoStore = todoStore
        self.listener = listener
        super.init(presenter: presenter)
    }

    override func didBecomeActive() {
        presenter.listener = self
        render()
    }

    override func willResignActive() {
        presenter.listener = nil
    }

    func handle(_ action: TodoDetailViewAction) {
        switch action {
        case .toggleDoneTapped:
            todoStore.toggle(todoID)
            render()
        case .backTapped:
            listener?.didRequestCloseDetail()
        }
    }

    private func render() {
        guard let todo = todoStore.find(todoID) else {
            preconditionFailure("Todo \(todoID) disappeared while its detail was open")
        }
        presenter.render(TodoDetailViewState(title: todo.title, isDone: todo.isDone))
    }
}

final class TodoDetailRouter: ViewableRouter<TodoDetailInteractor, any TodoDetailViewControllable>, TodoDetailRouting {
    let todoID: Int64

    init(interactor: TodoDetailInteractor, viewController: any TodoDetailViewControllable, todoID: Int64) {
        self.todoID = todoID
        super.init(interactor: interactor, viewController: viewController)
    }
}
