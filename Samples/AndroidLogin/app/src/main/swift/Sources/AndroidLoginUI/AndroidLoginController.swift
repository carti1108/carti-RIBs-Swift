import LoginShared
import RIBs
import RIBsAndroid

/// JNI 진입점이 부르는 한 덩어리. 렌더러·뷰 팩토리·`LoginApp`을 묶어 시작·입력·뒤로 가기·저장·종료를 제공한다.
@MainActor
public final class AndroidLoginController {
    private let renderer: AndroidRenderer
    private let host: AndroidViewHost<RootScreen>
    private let viewFactory: AndroidLoginViewFactory
    private let app: LoginApp<AndroidLoginViewFactory>

    public init(authService: any AuthService, clock: any LoginClock = TaskSleepClock(), sink: @escaping (String) -> Void) {
        renderer = AndroidRenderer(sink: sink)
        host = AndroidViewHost(renderer: renderer)
        viewFactory = AndroidLoginViewFactory(renderer: renderer)
        app = LoginApp(viewFactory: viewFactory, authService: authService, clock: clock)
    }

    /// 저장 문자열이 깨졌으면 버리고 처음부터 시작한다. 되살렸으면 true.
    @discardableResult
    public func start(savedState: String?) -> Bool {
        do {
            try app.start(host: host, savedState: savedState)
            return savedState != nil
        } catch {
            // nil은 디코딩하지 않으므로 던지지 않는다.
            try? app.start(host: host, savedState: nil)
            return false
        }
    }

    public func dispatch(screenID: Int64, action: String, argument: String) -> Bool {
        renderer.dispatch(screenID: screenID, action: action, argument: argument)
    }

    /// 타입 있는 통로로 그릴 LoggedOut 화면을 화면 트리의 `id`로 찾는다.
    public func loggedOutScreen(id: Int64) -> LoggedOutScreen? {
        viewFactory.loggedOutScreen(id: id)
    }

    public func handleBackPress() -> Bool { app.handleBackPress() }

    public func saveState() -> String { app.saveState() }

    public func stop() { app.stop() }

    public var encodedTree: String { renderer.encodedTree }
}
