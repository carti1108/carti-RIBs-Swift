import JavaScriptKit

/// 웹 뷰가 구현한다. 이 샘플은 `features/logged-in/view.js`가 구현한다.
@JS protocol LoggedInViewBridge {
    /// 새 LoggedIn 화면이 생길 때 불린다. `host` 안에 화면을 그리고 `handle`로 입력을 보낸다.
    /// `content`는 자식 화면(할 일 목록·상세)이 들어갈 자리다. Swift가 채우므로 뷰는 원하는 위치에 넣기만 한다.
    func mount(host: JSObject, content: JSObject, handle: LoggedInScreenHandle)
    func render(userName: String, sessionSeconds: Int)
}

@JS final class LoggedInScreenHandle: Sendable {
    private let onLogoutTapped: @MainActor @Sendable () -> Void

    init(onLogoutTapped: @escaping @MainActor @Sendable () -> Void) {
        self.onLogoutTapped = onLogoutTapped
    }

    @JS func logoutTapped() {
        MainActor.assumeIsolated { onLogoutTapped() }
    }
}
