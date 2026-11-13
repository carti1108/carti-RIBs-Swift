import RIBs

/// 루트 뷰 계약. 자식 RIB 화면 하나를 보여 준다. 플랫폼이 구현한다.
@MainActor
public protocol RootViewControllable: ViewControllable {
    func showScreen(_ screen: any ViewControllable)
    func hideScreen(_ screen: any ViewControllable)
}

@MainActor
public protocol RootDependency: Dependency {
    var viewFactory: any LoginViewFactory { get }
    var authService: any AuthService { get }
    var clock: any LoginClock { get }
}

final class RootComponent: Component<any RootDependency>, LoggedOutDependency, LoggedInDependency {
    var viewFactory: any LoginViewFactory { dependency.viewFactory }
    var authService: any AuthService { dependency.authService }
    var clock: any LoginClock { dependency.clock }
}

final class RootBuilder<Factory: LoginViewFactory>: Builder<any RootDependency> {
    private let factory: Factory

    init(dependency: any RootDependency, factory: Factory) {
        self.factory = factory
        super.init(dependency: dependency)
    }

    func build() -> RootRouter<Factory.RootView> {
        let component = RootComponent(dependency: dependency)
        return RootRouter(
            interactor: RootInteractor(),
            viewController: factory.makeRootView(),
            loggedOutBuilder: LoggedOutBuilder(dependency: component),
            loggedInBuilder: LoggedInBuilder(dependency: component)
        )
    }
}

/// Interactor → Router. RIBs-iOS 템플릿의 `RootRouting`.
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

    /// Router가 만들어질 때 자신을 넣는다(RIBs-iOS 템플릿과 같음).
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
    private let loggedOutBuilder: LoggedOutBuilder
    private let loggedInBuilder: LoggedInBuilder
    private var loggedOut: LoggedOutRouter?
    private var loggedIn: LoggedInRouter?

    init(
        interactor: RootInteractor,
        viewController: RootView,
        loggedOutBuilder: LoggedOutBuilder,
        loggedInBuilder: LoggedInBuilder
    ) {
        self.loggedOutBuilder = loggedOutBuilder
        self.loggedInBuilder = loggedInBuilder
        super.init(interactor: interactor, viewController: viewController)
        interactor.router = self
    }

    /// 자식에게 먼저 맡긴다. 아무도 처리하지 않으면 false라서 플랫폼 기본 동작을 따른다.
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
