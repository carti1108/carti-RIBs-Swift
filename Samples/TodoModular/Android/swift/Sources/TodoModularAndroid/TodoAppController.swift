import FeatureLoggedInAndroid
import FeatureLoggedInInterface
import FeatureLoggedOutAndroid
import FeatureLoggedOutInterface
import FeatureTodoDetailAndroid
import FeatureTodoDetailInterface
import FeatureTodoListAndroid
import FeatureTodoListInterface
import RIBs
import RIBsAndroid
import TodoAndroidSupport
import TodoAppRoot
import TodoCore

extension HostRootScreen: RootViewControllable {}

/// 피처별 Android 뷰 팩토리를 모아 `TodoAppViewFactory`를 채운다. 피처 화면 모듈을 모두 아는 곳은 여기뿐이다.
@MainActor
final class AndroidAppViewFactory: TodoAppViewFactory {
    private let context: ScreenContext
    private let loggedOut: LoggedOutAndroidViewFactory
    private let loggedIn: LoggedInAndroidViewFactory
    private let todoList: TodoListAndroidViewFactory
    private let todoDetail: TodoDetailAndroidViewFactory

    init(context: ScreenContext) {
        self.context = context
        loggedOut = LoggedOutAndroidViewFactory(context: context)
        loggedIn = LoggedInAndroidViewFactory(context: context)
        todoList = TodoListAndroidViewFactory(context: context)
        todoDetail = TodoDetailAndroidViewFactory(context: context)
    }

    func makeRootView() -> HostRootScreen { HostRootScreen(context: context) }
    func makeLoggedOutView() -> any LoggedOutViewContract { loggedOut.makeLoggedOutView() }
    func makeLoggedInView() -> any LoggedInViewContract { loggedIn.makeLoggedInView() }
    func makeTodoListView() -> any TodoListViewContract { todoList.makeTodoListView() }
    func makeTodoDetailView() -> any TodoDetailViewContract { todoDetail.makeTodoDetailView() }
}

/// 전체 앱. `TodoAppRoot`의 `TodoApp`을 Android 렌더러에 붙인다.
@MainActor
public final class TodoAppController: RibController {
    private let stack: RenderStack
    private let app: TodoApp<AndroidAppViewFactory>

    public init(authService: any AuthService, clock: any TodoClock = TaskSleepClock(), sink: @escaping (String) -> Void) {
        stack = RenderStack(sink: sink)
        app = TodoApp(viewFactory: AndroidAppViewFactory(context: stack.context), authService: authService, clock: clock)
    }

    @discardableResult
    public func start(savedState: String?) -> Bool {
        do {
            try app.start(host: stack.host, savedState: savedState)
            return savedState != nil
        } catch {
            // 저장값이 깨졌으면 버리고 처음부터 시작한다. nil은 디코딩하지 않으므로 던지지 않는다.
            try? app.start(host: stack.host, savedState: nil)
            return false
        }
    }

    public func screen<Screen: AndroidScreen>(id: Int64, as type: Screen.Type) -> Screen? {
        stack.registry.screen(id: id, as: type)
    }

    public func handleBackPress() -> Bool { app.handleBackPress() }
    public func saveState() -> String? { app.saveState() }
    public func stop() { app.stop() }
    public var encodedTree: String { stack.renderer.encodedTree }
}
