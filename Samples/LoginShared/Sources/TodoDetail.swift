import RIBs

@MainActor
public protocol TodoDetailPresentableListener: AnyObject {
    func didTapToggleDone()
    func didTapBack()
}

@MainActor
public protocol TodoDetailPresentable: Presentable {
    var listener: (any TodoDetailPresentableListener)? { get set }
    func showTodo(title: String, isDone: Bool)
}

@MainActor
public protocol TodoDetailViewControllable: ViewControllable {}

@MainActor
public protocol TodoDetailViewContract: TodoDetailPresentable, TodoDetailViewControllable {}

@MainActor
protocol TodoDetailDependency: Dependency {
    var viewFactory: any LoginViewFactory { get }
    var todoStore: TodoStore { get }
}

/// 자식 → 부모: 상세를 닫아 달라는 의도. 닫는 일(라우팅)은 부모가 한다.
@MainActor
protocol TodoDetailListener: AnyObject {
    func didRequestCloseDetail()
}

final class TodoDetailBuilder: Builder<any TodoDetailDependency> {
    /// `todoID`가 저장소에 없으면 nil을 돌려준다(복원 시 사라진 항목 등).
    func build(listener: any TodoDetailListener, todoID: Int64) -> TodoDetailRouter? {
        guard dependency.todoStore.find(todoID) != nil else { return nil }
        let view = dependency.viewFactory.makeTodoDetailView()
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

    func didTapToggleDone() {
        todoStore.toggle(todoID)
        render()
    }

    func didTapBack() { listener?.didRequestCloseDetail() }

    private func render() {
        guard let todo = todoStore.find(todoID) else {
            preconditionFailure("Todo \(todoID) disappeared while its detail was open")
        }
        presenter.showTodo(title: todo.title, isDone: todo.isDone)
    }
}

final class TodoDetailRouter: ViewableRouter<TodoDetailInteractor, any TodoDetailViewControllable> {
    let todoID: Int64

    init(interactor: TodoDetailInteractor, viewController: any TodoDetailViewControllable, todoID: Int64) {
        self.todoID = todoID
        super.init(interactor: interactor, viewController: viewController)
    }
}
