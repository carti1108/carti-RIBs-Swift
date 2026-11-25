import FeatureLoggedIn
import FeatureLoggedInInterface
import FeatureLoggedOut
import FeatureLoggedOutInterface
import FeatureTodoDetail
import FeatureTodoDetailInterface
import FeatureTodoList
import FeatureTodoListInterface
import RIBs
import TodoCore
import TodoData

/// 조립 모듈(ADR-0024). 피처 Impl을 아는 곳은 여기 하나다.

/// 루트 뷰 계약. 자식 RIB 화면 하나를 보여 준다. 플랫폼이 구현한다.
@MainActor
public protocol RootViewControllable: ViewControllable {
    func showScreen(_ screen: any ViewControllable)
    func hideScreen(_ screen: any ViewControllable)
}

/// 플랫폼이 구현하는 앱 전체 뷰 팩토리. 피처별 팩토리를 모두 따른다.
/// 루트 뷰만 연관 타입이다. `LaunchRouter`·`ViewHost`가 구체 뷰 타입을 요구한다(ADR-0008).
@MainActor
public protocol TodoAppViewFactory:
    LoggedOutViewFactory, LoggedInViewFactory, TodoListViewFactory, TodoDetailViewFactory
{
    associatedtype RootView: RootViewControllable
    func makeRootView() -> RootView
}

/// 플랫폼 진입점. `start`/`stop`으로 트리를 시작하고 끝낸다.
@MainActor
public final class TodoApp<Factory: TodoAppViewFactory> {
    private let router: RootRouter<Factory.RootView>

    /// `todoRepository`를 주지 않으면 샘플 서버(`SampleTodoServer`)에서 가져오는 저장소를 쓴다.
    /// 실제 앱은 플랫폼의 전송 구현으로 만든 `RemoteTodoRepository`를 넘긴다(ADR-0032).
    public init(
        viewFactory: Factory,
        authService: any AuthService,
        todoRepository: (any TodoRepository)? = nil,
        clock: any TodoClock = TaskSleepClock()
    ) {
        let component = RootComponent(
            viewFactory: viewFactory,
            authService: authService,
            todoRepository: todoRepository ?? RemoteTodoRepository(client: TodoAPIClient(transport: SampleTodoServer())),
            clock: clock
        )
        router = RootRouter(
            interactor: RootInteractor(),
            viewController: viewFactory.makeRootView(),
            loggedOutBuilder: LoggedOutBuilder(dependency: component, viewFactory: viewFactory),
            loggedInBuilder: LoggedInBuilder(dependency: component, viewFactory: viewFactory)
        )
    }

    /// `savedState`가 깨졌으면 트리를 시작하지 않고 던진다. 플랫폼은 저장값을 버리고 nil로 다시 부르면 된다.
    public func start(
        host: some ViewHost<Factory.RootView>,
        savedState: String? = nil
    ) throws(RibStateDecodingError) {
        let state = try savedState.map { encoded throws(RibStateDecodingError) in try RibState(decoding: encoded) }
        router.launch(from: host, savedInstanceState: state)
    }

    public func saveState() -> String { router.saveInstanceState().encodedString() }

    public func handleBackPress() -> Bool { router.handleBackPress() }

    public func stop() { router.shutdown() }
}

/// 피처 Dependency를 모두 채우고, 자식 Builder를 실제 Impl로 만들어 준다.
final class RootComponent: EmptyComponent, LoggedOutDependency, LoggedInDependency {
    let authService: any AuthService
    let todoRepository: any TodoRepository
    let clock: any TodoClock
    private let viewFactory: any TodoListViewFactory & TodoDetailViewFactory

    init(
        viewFactory: any TodoListViewFactory & TodoDetailViewFactory,
        authService: any AuthService,
        todoRepository: any TodoRepository,
        clock: any TodoClock
    ) {
        self.viewFactory = viewFactory
        self.authService = authService
        self.todoRepository = todoRepository
        self.clock = clock
        super.init()
    }

    func makeTodoListBuilder(dependency: any TodoListDependency) -> any TodoListBuildable {
        TodoListBuilder(dependency: dependency, viewFactory: viewFactory)
    }

    func makeTodoDetailBuilder(dependency: any TodoDetailDependency) -> any TodoDetailBuildable {
        TodoDetailBuilder(dependency: dependency, viewFactory: viewFactory)
    }
}

@MainActor
protocol RootRouting: AnyObject {
    func routeToLoggedOut()
    func routeAwayFromLoggedOut()
    func routeToLoggedIn(userName: String)
    func routeAwayFromLoggedIn()
}

/// 저장 상태: 로그인한 사용자 이름. 되살릴 때 이름이 있으면 로그인 화면을 건너뛴다.
final class RootInteractor: Interactor, LoggedOutListener, LoggedInListener {
    static let userNameKey = "userName"

    weak var router: (any RootRouting)?
    private var userName: String?

    override func didBecomeActive() {
        if let restoredUser = savedInstanceState?[Self.userNameKey]?.stringValue {
            didLogin(userName: restoredUser)
        } else {
            router?.routeToLoggedOut()
        }
    }

    override func onSaveInstanceState(_ outState: inout [String: RibValue]) {
        outState[Self.userNameKey] = userName.map(RibValue.string) ?? .null
    }

    func didLogin(userName: String) {
        self.userName = userName
        router?.routeAwayFromLoggedOut()
        router?.routeToLoggedIn(userName: userName)
    }

    func didRequestLogout() {
        userName = nil
        router?.routeAwayFromLoggedIn()
        router?.routeToLoggedOut()
    }
}

final class RootRouter<RootView: RootViewControllable>: LaunchRouter<RootInteractor, RootView>, RootRouting {
    private let loggedOutBuilder: any LoggedOutBuildable
    private let loggedInBuilder: any LoggedInBuildable
    private var loggedOut: (any ViewableRouting)?
    private var loggedIn: (any LoggedInRouting)?

    init(
        interactor: RootInteractor,
        viewController: RootView,
        loggedOutBuilder: any LoggedOutBuildable,
        loggedInBuilder: any LoggedInBuildable
    ) {
        self.loggedOutBuilder = loggedOutBuilder
        self.loggedInBuilder = loggedInBuilder
        super.init(interactor: interactor, viewController: viewController)
        interactor.router = self
    }

    override func handleBackPress() -> Bool {
        loggedIn?.handleBackPress() ?? false
    }

    func routeToLoggedOut() {
        guard loggedOut == nil else { return }
        let child = loggedOutBuilder.build(listener: interactor)
        attachChild(child)
        viewController.showScreen(child.viewControllable)
        loggedOut = child
    }

    func routeAwayFromLoggedOut() {
        guard let child = loggedOut else { return }
        detachChild(child)
        viewController.hideScreen(child.viewControllable)
        loggedOut = nil
    }

    func routeToLoggedIn(userName: String) {
        guard loggedIn == nil else { return }
        let child = loggedInBuilder.build(listener: interactor, userName: userName)
        attachChild(child)
        viewController.showScreen(child.viewControllable)
        loggedIn = child
    }

    func routeAwayFromLoggedIn() {
        guard let child = loggedIn else { return }
        detachChild(child)
        viewController.hideScreen(child.viewControllable)
        loggedIn = nil
    }
}
