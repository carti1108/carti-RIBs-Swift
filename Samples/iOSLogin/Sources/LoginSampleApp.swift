import Foundation
import LoginShared
import RIBsSwiftUI
import SwiftUI

@main
struct LoginSampleApp: App {
    @State private var launcher = AppLauncher()

    var body: some Scene {
        WindowGroup {
            LoginRootView(launcher: launcher)
        }
    }
}

/// 장면의 루트 뷰. `@SceneStorage`는 `App`이 아니라 장면 안의 `View`에 있어야 시스템이 값을 저장·복원한다.
private struct LoginRootView: View {
    let launcher: AppLauncher
    /// 공유 코드가 만든 `RibState` 문자열. 시스템이 장면을 되살릴 때 돌려준다.
    @SceneStorage("ribState") private var savedState = ""
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        RIBSlotView(slot: launcher.host.slot)
            .onAppear { launcher.start(savedState: savedState) }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { savedState = launcher.saveState() }
            }
    }
}

/// 공유 코드의 `LoginApp`을 시작하고 루트 뷰를 창에 붙인다.
@MainActor
final class AppLauncher {
    /// 샘플 서버 응답 지연. 로딩 표시를 눈으로 확인할 수 있을 만큼만 둔다.
    private static let defaultLoginDelay: Duration = .milliseconds(800)

    let host = SwiftUIViewHost<RootScreen>()
    private let app = LoginApp(
        viewFactory: SwiftUIViewFactory(),
        authService: DelayedAuthService(delay: AppLauncher.loginDelay)
    )
    private var isStarted = false

    /// UI 테스트는 `-loginDelayMillis <ms>` 실행 인자로 지연을 늘려 잠깐 보이는 로딩 상태를 확실히 잡는다.
    private static var loginDelay: Duration {
        let override = UserDefaults.standard.integer(forKey: "loginDelayMillis")
        return override > 0 ? .milliseconds(override) : defaultLoginDelay
    }

    func start(savedState: String) {
        guard !isStarted else { return }
        isStarted = true
        do {
            try app.start(host: host, savedState: savedState.isEmpty ? nil : savedState)
        } catch {
            // 저장값이 깨졌으면 버리고 처음부터 시작한다.
            try? app.start(host: host, savedState: nil)
        }
    }

    func saveState() -> String { app.saveState() }
}
