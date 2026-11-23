import RIBs

/// 머리말에 그릴 값. 자식 화면은 상태가 아니라 `LoggedInViewControllable`로 붙인다(ADR-0025).
public struct LoggedInViewState: Equatable, Sendable {
    public var userName: String
    public var sessionSeconds: Int64

    public init(userName: String, sessionSeconds: Int64 = 0) {
        self.userName = userName
        self.sessionSeconds = sessionSeconds
    }
}

/// 뷰 → 공유 코드: 사용자 입력.
public enum LoggedInViewAction: Equatable, Sendable {
    case logoutTapped
}

@MainActor
public protocol LoggedInPresentableListener: AnyObject {
    func handle(_ action: LoggedInViewAction)
}

/// Interactor → 뷰: 머리말(사용자 이름, 세션 시간)을 그린다.
@MainActor
public protocol LoggedInPresentable: Presentable {
    /// 활성 구간에만 설정된다. 플랫폼은 `weak`로 둔다.
    var listener: (any LoggedInPresentableListener)? { get set }
    func render(_ state: LoggedInViewState)
}

/// Router → 뷰: 자식 화면을 붙이고 뗀다. RIBs-iOS 템플릿의 `LoggedInViewControllable`.
@MainActor
public protocol LoggedInViewControllable: ViewControllable {
    func showScreen(_ screen: any ViewControllable)
    func hideScreen(_ screen: any ViewControllable)
}

@MainActor
public protocol LoggedInViewContract: LoggedInPresentable, LoggedInViewControllable {}

@MainActor
protocol LoggedInDependency: Dependency {
    var viewFactory: any LoginViewFactory { get }
    var clock: any LoginClock { get }
}

@MainActor
protocol LoggedInListener: AnyObject {
    func didRequestLogout()
}

/// 목록과 상세가 같은 `TodoStore`를 쓰도록 여기서 한 번만 만든다.
final class LoggedInComponent: Component<any LoggedInDependency>, TodoListDependency, TodoDetailDependency {
    var viewFactory: any LoginViewFactory { dependency.viewFactory }
    var todoStore: TodoStore { shared { TodoStore() } }
}

final class LoggedInBuilder: Builder<any LoggedInDependency> {
    func build(listener: any LoggedInListener, userName: String) -> LoggedInRouter {
        let component = LoggedInComponent(dependency: dependency)
        let view = dependency.viewFactory.makeLoggedInView()
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
            listBuilder: TodoListBuilder(dependency: component),
            detailBuilder: TodoDetailBuilder(dependency: component)
        )
    }
}

@MainActor
protocol LoggedInRouting: AnyObject {
    var openDetailID: Int64? { get }
    func routeToList()
    func routeToDetail(todoID: Int64)
    func routeAwayFromDetail()
}

/// 목록을 기본 화면으로 두고 상세를 위에 쌓는다. 뒤로 가기는 열린 상세를 닫고, 닫을 것이 없으면 false를 돌려준다.
/// 저장 상태: 완료한 할 일과 열려 있던 상세 id.
final class LoggedInInteractor: PresentableInteractor<any LoggedInPresentable>, LoggedInPresentableListener,
    TodoListListener, TodoDetailListener, SessionTimerListener
{
    static let doneIDsKey = "doneIds"
    static let openDetailIDKey = "openDetailId"

    weak var router: (any LoggedInRouting)?
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

final class LoggedInRouter: ViewableRouter<LoggedInInteractor, any LoggedInViewControllable>, LoggedInRouting {
    private let listBuilder: TodoListBuilder
    private let detailBuilder: TodoDetailBuilder
    private var list: TodoListRouter?
    private var detail: TodoDetailRouter?

    init(
        interactor: LoggedInInteractor,
        viewController: any LoggedInViewControllable,
        listBuilder: TodoListBuilder,
        detailBuilder: TodoDetailBuilder
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
        viewController.showScreen(child.viewControllable)
        list = child
    }

    func routeToDetail(todoID: Int64) {
        guard detail == nil, let child = detailBuilder.build(listener: interactor, todoID: todoID) else { return }
        attachChild(child)
        viewController.showScreen(child.viewControllable)
        detail = child
    }

    func routeAwayFromDetail() {
        guard let child = detail else { return }
        detachChild(child)
        viewController.hideScreen(child.viewControllable)
        detail = nil
        if let list { viewController.showScreen(list.viewControllable) }
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
    private let clock: any LoginClock

    init(clock: any LoginClock) {
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
