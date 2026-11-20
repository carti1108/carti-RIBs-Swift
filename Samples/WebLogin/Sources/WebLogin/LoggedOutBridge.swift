import JavaScriptKit
import LoginShared

// BridgeJS가 JS로 내보내는 층. 격리 없는 타입만 `@JS`로 두고 `@MainActor` 뷰 계약은 감춘다.
// Wasm은 단일 스레드라 모든 호출이 메인에서 온다. `MainActor.assumeIsolated`로 확인한다.

/// 웹 뷰가 구현한다. 뷰를 무엇으로 만들지는 정하지 않는다. 이 샘플은 `views/logged-out-view.js`가 구현한다.
/// 객체 하나가 LoggedOut 화면 여러 개를 차례로 맡는다(로그아웃할 때마다 새 화면이 생긴다).
@JS protocol LoggedOutViewBridge {
    /// 새 LoggedOut 화면이 생길 때 불린다. `host` 안에 화면을 그리고 `handle`로 입력을 보낸다.
    func mount(host: JSObject, handle: LoggedOutScreenHandle)
    /// 가장 최근에 `mount`한 화면의 상태를 그린다.
    func render(errorMessage: String?, isLoading: Bool)
}

/// 웹 뷰가 `mount`에서 받아 쥐고 입력을 보낸다. 화면이 이미 내려갔으면 호출은 아무 일도 하지 않는다.
@JS final class LoggedOutScreenHandle: Sendable {
    private let onLoginTapped: @MainActor @Sendable (String) -> Void

    init(onLoginTapped: @escaping @MainActor @Sendable (String) -> Void) {
        self.onLoginTapped = onLoginTapped
    }

    @JS func loginTapped(rawName: String) {
        MainActor.assumeIsolated { onLoginTapped(rawName) }
    }
}

/// 브라우저 쪽 진입점. 웹 뷰 구현을 넘겨 앱을 시작한다.
@JS func startLoginApp(loggedOutView: any LoggedOutViewBridge) {
    nonisolated(unsafe) let loggedOutView = loggedOutView
    MainActor.assumeIsolated { WebLoginMain.start(loggedOutView: loggedOutView) }
}
