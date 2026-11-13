import JavaScriptEventLoop
import JavaScriptKit
import LoginShared
import RIBsWeb

/// 브라우저 진입점. 공유 코드의 `LoginApp`을 시작하고 루트 화면을 `#app`에 붙인다.
/// E2E 테스트는 `?loginDelayMillis=<ms>`로 로그인 지연을 늘려 로딩 상태를 확실히 잡는다.
@MainActor
enum WebLoginMain {
    static let defaultLoginDelay: Duration = .milliseconds(800)
    static var app: LoginApp<WebViewFactory>?
    static var renderer: SlotRenderer?

    static func loginDelay() -> Duration {
        let search = JSObject.global.location.search.string ?? ""
        let params = JSObject.global.URLSearchParams.function!.new(search)
        guard let raw = params.get!("loginDelayMillis").string, let millis = Int(raw), millis > 0 else {
            return defaultLoginDelay
        }
        return .milliseconds(millis)
    }

    static func start() {
        let host = WebViewHost<RootScreen>()
        let container = JSObject.global.document.getElementById("app").object!
        renderer = SlotRenderer(slot: host.slot, container: container)
        let app = LoginApp(viewFactory: WebViewFactory(), authService: DelayedAuthService(delay: loginDelay()))
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

/// 탭 단위 `sessionStorage`에 `LoginApp.saveState()` 문자열을 둔다. 새로고침하면 같은 화면으로 돌아온다.
/// 저장은 페이지를 떠나거나 숨길 때만 한다. `pagehide`는 새로고침·이동·탭 닫기에서, `visibilitychange`(hidden)는
/// 모바일에서 백그라운드로 갈 때 온다. 화면 전환마다 저장하지 않는 이유: 라우팅 도중(자식을 붙이는 중)에 트리를 저장하면
/// 반쯤 바뀐 상태가 남을 수 있고, 위 두 이벤트가 떠나기 전 마지막 기회를 이미 보장한다.
@MainActor
enum SavedStateStore {
    static let key = "ribs.login.savedState"
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

JavaScriptEventLoop.installGlobalExecutor()
WebLoginMain.start()
