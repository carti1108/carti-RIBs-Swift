import FeatureLoggedInInterface
import FeatureLoggedInWeb
import FeatureLoggedOutInterface
import FeatureLoggedOutWeb
import FeatureTodoDetailInterface
import FeatureTodoDetailWeb
import FeatureTodoListInterface
import FeatureTodoListWeb
import JavaScriptKit
import RIBsWeb
import TodoAppRoot
import TodoCore
import TodoWebSupport

extension HostRootScreen: RootViewControllable {}

/// 전체 앱의 뷰 팩토리. 피처별 웹 뷰 팩토리를 모은다.
@MainActor
final class WebViewFactory: TodoAppViewFactory {
    private let loggedOut: LoggedOutWebViewFactory
    private let loggedIn: LoggedInWebViewFactory
    private let todoList: TodoListWebViewFactory
    private let todoDetail: TodoDetailWebViewFactory

    init(
        loggedOut: LoggedOutWebViewFactory,
        loggedIn: LoggedInWebViewFactory,
        todoList: TodoListWebViewFactory,
        todoDetail: TodoDetailWebViewFactory
    ) {
        self.loggedOut = loggedOut
        self.loggedIn = loggedIn
        self.todoList = todoList
        self.todoDetail = todoDetail
    }

    func makeRootView() -> HostRootScreen { HostRootScreen() }
    func makeLoggedOutView() -> any LoggedOutViewContract { loggedOut.makeLoggedOutView() }
    func makeLoggedInView() -> any LoggedInViewContract { loggedIn.makeLoggedInView() }
    func makeTodoListView() -> any TodoListViewContract { todoList.makeTodoListView() }
    func makeTodoDetailView() -> any TodoDetailViewContract { todoDetail.makeTodoDetailView() }
}

/// 공유 코드의 `TodoApp`을 시작하고 루트 화면을 `#app`에 붙인다. JS가 `startTodoApp`으로 부른다.
@MainActor
enum TodoWebApp {
    private static var app: TodoApp<WebViewFactory>?
    private static var renderer: SlotRenderer?

    static func start(viewFactory: WebViewFactory) {
        precondition(app == nil, "startTodoApp called twice")
        let host = WebViewHost<HostRootScreen>()
        renderer = SlotRenderer(slot: host.slot, container: Page.appContainer)
        let app = TodoApp(viewFactory: viewFactory, authService: DelayedAuthService(delay: Page.loginDelay()))
        do {
            try app.start(host: host, savedState: SavedStateStore.load())
        } catch {
            // 깨진 저장값은 버리고 처음부터 시작한다. nil로 부르면 던지지 않는다.
            SavedStateStore.clear()
            try! app.start(host: host, savedState: nil)
        }
        self.app = app
        SavedStateStore.saveOnPageHide { app.saveState() }
    }
}

/// 페이지에서 읽는 값. E2E 테스트는 `?loginDelayMillis=<ms>`로 로그인 지연을 바꾼다.
@MainActor
enum Page {
    static let defaultLoginDelay: Duration = .milliseconds(800)

    static var appContainer: JSObject { JSObject.global.document.getElementById("app").object! }

    static func loginDelay() -> Duration {
        let search = JSObject.global.location.search.string ?? ""
        let params = JSObject.global.URLSearchParams.function!.new(search)
        guard let raw = params.get!("loginDelayMillis").string, let millis = Int(raw), millis > 0 else {
            return defaultLoginDelay
        }
        return .milliseconds(millis)
    }
}

/// 탭 단위 `sessionStorage`에 `TodoApp.saveState()` 문자열을 둔다. 새로고침하면 같은 화면으로 돌아온다(ADR-0013).
/// 저장은 페이지를 떠나거나 숨길 때만 한다. 라우팅 도중에 저장하면 반쯤 바뀐 트리가 남을 수 있다.
@MainActor
enum SavedStateStore {
    static let key = "ribs.todomodular.savedState"
    private static var listeners: [JSClosure] = []
    private static var storage: JSObject { JSObject.global.sessionStorage.object! }

    static func load() -> String? { storage.getItem!(key).string }

    static func clear() { _ = storage.removeItem!(key) }

    static func saveOnPageHide(_ snapshot: @escaping @MainActor () -> String) {
        let save = { MainActor.assumeIsolated { _ = storage.setItem!(key, snapshot()) } }
        let onPageHide = JSClosure { _ in
            save()
            return .undefined
        }
        // 새로고침의 pagehide 시점에는 visibilityState가 아직 visible일 수 있어 조건 없이 저장한다.
        let onVisibilityChange = JSClosure { _ in
            if JSObject.global.document.visibilityState.string == "hidden" { save() }
            return .undefined
        }
        listeners += [onPageHide, onVisibilityChange]
        _ = JSObject.global.addEventListener!("pagehide", onPageHide)
        _ = JSObject.global.document.object!.addEventListener!("visibilitychange", onVisibilityChange)
    }
}
