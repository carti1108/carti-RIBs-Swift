import FeatureLoggedInInterface
import FeatureLoggedInUI
import FeatureLoggedOutInterface
import FeatureLoggedOutUI
import FeatureTodoDetailInterface
import FeatureTodoDetailUI
import FeatureTodoListInterface
import FeatureTodoListUI
import Foundation
import RIBs
import RIBsSwiftUI
import SwiftUI
import TodoAppRoot
import TodoCore

@main
struct TodoModularApp: App {
    @State private var launcher = AppLauncher()

    var body: some Scene {
        WindowGroup {
            TodoRootView(launcher: launcher)
        }
    }
}

/// `@SceneStorage`는 장면 안의 `View`에 있어야 시스템이 값을 저장·복원한다.
private struct TodoRootView: View {
    let launcher: AppLauncher
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

/// 루트 RIB의 뷰. 자식 RIB 화면 하나를 보여 준다.
@MainActor
final class RootScreen: RootViewControllable, SwiftUIRenderable {
    private let slot = RIBScreenSlot()

    func showScreen(_ screen: any ViewControllable) { slot.show(screen) }
    func hideScreen(_ screen: any ViewControllable) { slot.hide(screen) }

    func makeView() -> AnyView {
        AnyView(RIBSlotView(slot: slot).animation(.default, value: slot.current.map(ObjectIdentifier.init)))
    }
}

/// 피처 UI 모듈의 팩토리를 모아 `TodoAppViewFactory`를 채운다. 앱에서 피처 UI를 모두 아는 곳은 여기뿐이다.
@MainActor
final class AppViewFactory: TodoAppViewFactory {
    private let loggedOut = LoggedOutScreenFactory()
    private let loggedIn = LoggedInScreenFactory()
    private let todoList = TodoListScreenFactory()
    private let todoDetail = TodoDetailScreenFactory()

    func makeRootView() -> RootScreen { RootScreen() }
    func makeLoggedOutView() -> any LoggedOutViewContract { loggedOut.makeLoggedOutView() }
    func makeLoggedInView() -> any LoggedInViewContract { loggedIn.makeLoggedInView() }
    func makeTodoListView() -> any TodoListViewContract { todoList.makeTodoListView() }
    func makeTodoDetailView() -> any TodoDetailViewContract { todoDetail.makeTodoDetailView() }
}

@MainActor
final class AppLauncher {
    /// 샘플 서버 응답 지연. 로딩 표시를 눈으로 확인할 수 있을 만큼만 둔다.
    private static let defaultLoginDelay: Duration = .milliseconds(800)

    let host = SwiftUIViewHost<RootScreen>()
    private let app = TodoApp(
        viewFactory: AppViewFactory(),
        authService: DelayedAuthService(delay: AppLauncher.loginDelay)
    )
    private var isStarted = false

    /// UI 테스트는 `-loginDelayMillis <ms>` 실행 인자로 지연을 늘린다.
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
