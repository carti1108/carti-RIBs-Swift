import FeatureLoggedInInterface
import FeatureTodoDetailInterface
import FeatureTodoListInterface
import RIBs
import TodoCore

/// 목록과 상세가 같은 `TodoStore`를 쓰도록 여기서 한 번만 만든다.
final class LoggedInComponent: Component<any LoggedInDependency>, TodoListDependency, TodoDetailDependency {
    var todoStore: TodoStore { shared { TodoStore() } }
}

public final class LoggedInBuilder: Builder<any LoggedInDependency>, LoggedInBuildable {
    private let viewFactory: any LoggedInViewFactory

    public init(dependency: any LoggedInDependency, viewFactory: any LoggedInViewFactory) {
        self.viewFactory = viewFactory
        super.init(dependency: dependency)
    }

    public func build(listener: any LoggedInListener, userName: String) -> any LoggedInRouting {
        let component = LoggedInComponent(dependency: dependency)
        let view = viewFactory.makeLoggedInView()
        let interactor = LoggedInInteractor(
            presenter: view,
            userName: userName,
            todoStore: component.todoStore,
            listener: listener,
            sessionTimer: SessionTimerWorker(clock: dependency.clock)
        )
        return LoggedInRouter(
            interactor: interactor,
            viewController: view,
            listBuilder: dependency.makeTodoListBuilder(dependency: component),
            detailBuilder: dependency.makeTodoDetailBuilder(dependency: component)
        )
    }
}

@MainActor
protocol LoggedInInternalRouting: AnyObject {
    var openDetailID: Int64? { get }
    func routeToList()
    func routeToDetail(todoID: Int64)
    func routeAwayFromDetail()
}

/// 목록을 기본 화면으로 두고 상세를 그 위에 보여 준다. 뒤로 가기는 열린 상세를 닫고, 닫을 것이 없으면 false.
/// 저장 상태: 완료한 할 일과 열려 있던 상세 id.
final class LoggedInInteractor: PresentableInteractor<any LoggedInPresentable>, LoggedInPresentableListener,
    TodoListListener, TodoDetailListener, SessionTimerListener
{
    static let doneIDsKey = "doneIds"
    static let openDetailIDKey = "openDetailId"

    weak var router: (any LoggedInInternalRouting)?
    private var viewState: LoggedInViewState
    private let todoStore: TodoStore
    private weak var listener: (any LoggedInListener)?
    private let sessionTimer: SessionTimerWorker

    init(
        presenter: any LoggedInPresentable,
        userName: String,
        todoStore: TodoStore,
        listener: any LoggedInListener,
        sessionTimer: SessionTimerWorker
    ) {
        self.viewState = LoggedInViewState(userName: userName)
        self.todoStore = todoStore
        self.listener = listener
        self.sessionTimer = sessionTimer
        super.init(presenter: presenter)
        sessionTimer.listener = self
    }

    override func didBecomeActive() {
        presenter.listener = self
        presenter.render(viewState)
        if let doneIDs = savedInstanceState?[Self.doneIDsKey]?.listValue {
            todoStore.restoreDone(doneIDs.compactMap(\.intValue))
        }
        router?.routeToList()
        if let openID = savedInstanceState?[Self.openDetailIDKey]?.intValue {
            router?.routeToDetail(todoID: openID)
        }
        sessionTimer.start(self)
    }

    override func willResignActive() {
        presenter.listener = nil
        sessionTimer.stop()
    }

    override func onSaveInstanceState(_ outState: inout [String: RibValue]) {
        outState[Self.doneIDsKey] = .list(todoStore.doneIDs.map(RibValue.int))
        outState[Self.openDetailIDKey] = router?.openDetailID.map(RibValue.int) ?? .null
    }

    override func handleBackPress() -> Bool {
        guard let router, router.openDetailID != nil else { return false }
        router.routeAwayFromDetail()
        return true
    }

    func handle(_ action: LoggedInViewAction) {
        switch action {
        case .logoutTapped: listener?.didRequestLogout()
        case .detailDismissedByUser:
            guard isActive else { return }
            router?.routeAwayFromDetail()
        }
    }

    func sessionDidTick(seconds: Int64) {
        guard seconds != viewState.sessionSeconds else { return }
        viewState = LoggedInViewState(userName: viewState.userName, sessionSeconds: seconds)
        presenter.render(viewState)
    }

    func didSelectTodo(id: Int64) { router?.routeToDetail(todoID: id) }

    func didRequestCloseDetail() { router?.routeAwayFromDetail() }
}

final class LoggedInRouter: ViewableRouter<LoggedInInteractor, any LoggedInViewControllable>, LoggedInRouting,
    LoggedInInternalRouting
{
    private let listBuilder: any TodoListBuildable
    private let detailBuilder: any TodoDetailBuildable
    private var list: (any ViewableRouting)?
    private var detail: (any TodoDetailRouting)?

    init(
        interactor: LoggedInInteractor,
        viewController: any LoggedInViewControllable,
        listBuilder: any TodoListBuildable,
        detailBuilder: any TodoDetailBuildable
    ) {
        self.listBuilder = listBuilder
        self.detailBuilder = detailBuilder
        super.init(interactor: interactor, viewController: viewController)
        interactor.router = self
    }

    var openDetailID: Int64? { detail?.todoID }

    func routeToList() {
        guard list == nil else { return }
        let child = listBuilder.build(listener: interactor)
        attachChild(child)
        viewController.showList(child.viewControllable)
        list = child
    }

    func routeToDetail(todoID: Int64) {
        guard detail == nil, let child = detailBuilder.build(listener: interactor, todoID: todoID) else { return }
        attachChild(child)
        viewController.showDetail(child.viewControllable)
        detail = child
    }

    func routeAwayFromDetail() {
        guard let child = detail else { return }
        detachChild(child)
        viewController.hideDetail(child.viewControllable)
        detail = nil
    }
}

@MainActor
protocol SessionTimerListener: AnyObject {
    func sessionDidTick(seconds: Int64)
}

/// 로그인한 동안 1초마다 세션 시간을 알린다. Interactor가 비활성화되면 함께 멈춘다.
/// 뷰를 직접 그리지 않는다. 화면 상태는 Interactor 한 곳에서만 만든다.
final class SessionTimerWorker: Worker {
    static let tick: Duration = .seconds(1)

    weak var listener: (any SessionTimerListener)?
    private let clock: any TodoClock

    init(clock: any TodoClock) {
        self.clock = clock
        super.init()
    }

    override func didStart(_ interactorScope: any InteractorScope) {
        startTask { [weak self, clock] in
            var seconds: Int64 = 0
            while true {
                self?.listener?.sessionDidTick(seconds: seconds)
                do {
                    try await clock.sleep(for: Self.tick)
                } catch {
                    return
                }
                seconds += 1
            }
        }
    }
}
