import RIBs

// 통합 테스트용 샘플 트리: Root → LoggedOut ⇄ LoggedIn.
// RIB마다 Dependency / Component / Builder / Interactor / Router를 RIBs-iOS 템플릿 규약대로 둔다.

// MARK: - 공용 서비스

/// Root에서 만들어 자식 둘이 같이 쓰는 세션 저장소.
@MainActor
final class SessionStore {
    private(set) var user: String?
    func signIn(_ name: String) { user = name }
    func signOut() { user = nil }
}

// MARK: - Root

@MainActor
final class RootComponent: Component<any EmptyDependency>, LoggedOutDependency, LoggedInDependency {
    var sessionStore: SessionStore { shared { SessionStore() } }
}

@MainActor
final class RootBuilder: Builder<any EmptyDependency> {
    func build() -> RootRouter {
        let component = RootComponent(dependency: dependency)
        let interactor = RootInteractor()
        return RootRouter(
            interactor: interactor,
            viewController: FakeView(name: "root"),
            loggedOutBuilder: LoggedOutBuilder(dependency: component),
            loggedInBuilder: LoggedInBuilder(dependency: component)
        )
    }
}

@MainActor
protocol RootRouting: Routing {
    func routeToLoggedOut()
    func routeAwayFromLoggedOut()
    func routeToLoggedIn(userName: String)
    func routeAwayFromLoggedIn()
}

@MainActor
protocol RootInteractable: Interactable, LoggedOutListener, LoggedInListener {
    var router: (any RootRouting)? { get set }
}

@MainActor
final class RootInteractor: Interactor, RootInteractable {
    weak var router: (any RootRouting)?

    override func didBecomeActive() {
        router?.routeToLoggedOut()
    }

    func didLogin(userName: String) {
        router?.routeAwayFromLoggedOut()
        router?.routeToLoggedIn(userName: userName)
    }

    func didRequestLogout() {
        router?.routeAwayFromLoggedIn()
        router?.routeToLoggedOut()
    }
}

@MainActor
final class RootRouter: LaunchRouter<any RootInteractable, FakeView>, RootRouting {
    private let loggedOutBuilder: LoggedOutBuilder
    private let loggedInBuilder: LoggedInBuilder
    private var loggedOut: LoggedOutRouter?
    private var loggedIn: LoggedInRouter?

    init(
        interactor: any RootInteractable,
        viewController: FakeView,
        loggedOutBuilder: LoggedOutBuilder,
        loggedInBuilder: LoggedInBuilder
    ) {
        self.loggedOutBuilder = loggedOutBuilder
        self.loggedInBuilder = loggedInBuilder
        super.init(interactor: interactor, viewController: viewController)
        interactor.router = self
    }

    func routeToLoggedOut() {
        guard loggedOut == nil else { return }
        let router = loggedOutBuilder.build(withListener: interactor)
        loggedOut = router
        attachChild(router)
    }

    func routeAwayFromLoggedOut() {
        guard let loggedOut else { return }
        detachChild(loggedOut)
        self.loggedOut = nil
    }

    func routeToLoggedIn(userName: String) {
        guard loggedIn == nil else { return }
        let router = loggedInBuilder.build(withListener: interactor, userName: userName)
        loggedIn = router
        attachChild(router)
    }

    func routeAwayFromLoggedIn() {
        guard let loggedIn else { return }
        detachChild(loggedIn)
        self.loggedIn = nil
    }
}

// MARK: - LoggedOut (뷰가 Presentable을 구현)

@MainActor
protocol LoggedOutDependency: Dependency {
    var sessionStore: SessionStore { get }
}

/// 자식 → 부모: 사용자 의도로 표현한다. 라우팅은 부모가 정한다.
@MainActor
protocol LoggedOutListener: AnyObject {
    func didLogin(userName: String)
}

@MainActor
final class LoggedOutBuilder: Builder<any LoggedOutDependency> {
    func build(withListener listener: any LoggedOutListener) -> LoggedOutRouter {
        let view = LoggedOutView()
        let interactor = LoggedOutInteractor(presenter: view, sessionStore: dependency.sessionStore, listener: listener)
        return LoggedOutRouter(interactor: interactor, viewController: view)
    }
}

@MainActor
protocol LoggedOutPresentableListener: AnyObject {
    func login(name: String)
}

@MainActor
protocol LoggedOutPresentable: Presentable {
    var listener: (any LoggedOutPresentableListener)? { get set }
}

/// 뷰 입력을 해석해 리스너로 넘긴다. 공백만 있는 이름은 거른다.
@MainActor
final class LoggedOutView: LoggedOutPresentable, ViewControllable {
    weak var listener: (any LoggedOutPresentableListener)?
    private(set) var errorMessage: String?

    func didTapLogin(_ rawName: String) {
        let name = String(rawName.drop(while: \.isWhitespace).reversed().drop(while: \.isWhitespace).reversed())
        guard !name.isEmpty else {
            errorMessage = "이름을 입력하세요"
            return
        }
        errorMessage = nil
        listener?.login(name: name)
    }
}

@MainActor
final class LoggedOutInteractor: PresentableInteractor<any LoggedOutPresentable>, LoggedOutPresentableListener {
    let sessionStore: SessionStore
    private weak var listener: (any LoggedOutListener)?

    init(presenter: any LoggedOutPresentable, sessionStore: SessionStore, listener: any LoggedOutListener) {
        self.sessionStore = sessionStore
        self.listener = listener
        super.init(presenter: presenter)
        presenter.listener = self
    }

    func login(name: String) {
        sessionStore.signIn(name)
        listener?.didLogin(userName: name)
    }
}

@MainActor
final class LoggedOutRouter: ViewableRouter<LoggedOutInteractor, LoggedOutView> {}

// MARK: - LoggedIn (뷰 없음 + Worker)

@MainActor
protocol LoggedInDependency: Dependency {
    var sessionStore: SessionStore { get }
}

@MainActor
protocol LoggedInListener: AnyObject {
    func didRequestLogout()
}

@MainActor
final class LoggedInBuilder: Builder<any LoggedInDependency> {
    func build(withListener listener: any LoggedInListener, userName: String) -> LoggedInRouter {
        let interactor = LoggedInInteractor(
            userName: userName,
            sessionStore: dependency.sessionStore,
            listener: listener,
            heartbeat: HeartbeatWorker()
        )
        return LoggedInRouter(interactor: interactor)
    }
}

/// 로그인 동안 돌아가는 작업. Interactor가 비활성화되면 멈춘다.
@MainActor
final class HeartbeatWorker: Worker {
    private(set) var runningTask: Task<Void, Never>?
    private(set) var stopped = false

    override func didStart(_ interactorScope: any InteractorScope) {
        stopped = false
        runningTask = try? task { await suspendUntilCancelled() }
    }

    override func didStop() {
        stopped = true
    }
}

@MainActor
final class LoggedInInteractor: Interactor {
    let userName: String
    let sessionStore: SessionStore
    let heartbeat: HeartbeatWorker
    private weak var listener: (any LoggedInListener)?

    init(userName: String, sessionStore: SessionStore, listener: any LoggedInListener, heartbeat: HeartbeatWorker) {
        self.userName = userName
        self.sessionStore = sessionStore
        self.listener = listener
        self.heartbeat = heartbeat
        super.init()
    }

    override func didBecomeActive() {
        heartbeat.start(self)
    }

    func logout() {
        sessionStore.signOut()
        listener?.didRequestLogout()
    }
}

@MainActor
final class LoggedInRouter: Router<LoggedInInteractor> {}
