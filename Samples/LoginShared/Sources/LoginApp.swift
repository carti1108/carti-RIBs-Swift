import RIBs

/// 플랫폼 진입점. 뷰 팩토리와 인증 서비스를 받아 루트 RIB을 만들고, `start`/`stop`으로 트리를 시작하고 끝낸다.
@MainActor
public final class LoginApp<Factory: LoginViewFactory> {
    private let router: RootRouter<Factory.RootView>

    public init(viewFactory: Factory, authService: any AuthService, clock: any LoginClock = TaskSleepClock()) {
        let dependency = AppDependency(viewFactory: viewFactory, authService: authService, clock: clock)
        router = RootBuilder(dependency: dependency, factory: viewFactory).build()
    }

    /// `savedState`는 이전 실행에서 `saveState()`가 돌려준 문자열이다. 없으면 처음부터 시작한다.
    /// 문자열이 깨졌으면 트리를 시작하지 않고 던진다. 플랫폼은 저장값을 버리고 nil로 다시 부르면 된다.
    public func start(
        host: some ViewHost<Factory.RootView>,
        savedState: String? = nil
    ) throws(RibStateDecodingError) {
        let state = try savedState.map { encoded throws(RibStateDecodingError) in try RibState(decoding: encoded) }
        router.launch(from: host, savedInstanceState: state)
    }

    /// 플랫폼 상태 저장소에 넣을 문자열.
    public func saveState() -> String { router.saveInstanceState().encodedString() }

    /// 시스템 뒤로 가기. 트리가 처리하면 true, 아니면 플랫폼 기본 동작을 따른다.
    public func handleBackPress() -> Bool { router.handleBackPress() }

    public func stop() { router.shutdown() }
}

private final class AppDependency: RootDependency {
    let viewFactory: any LoginViewFactory
    let authService: any AuthService
    let clock: any LoginClock

    init(viewFactory: any LoginViewFactory, authService: any AuthService, clock: any LoginClock) {
        self.viewFactory = viewFactory
        self.authService = authService
        self.clock = clock
    }
}
