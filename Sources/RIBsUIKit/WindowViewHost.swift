#if canImport(UIKit)
import RIBs
import UIKit

/// 루트 RIB 화면을 `UIWindow`에 붙이는 `ViewHost`. RIBs-iOS `LaunchRouter.launch(from: UIWindow)` 자리.
@MainActor
public final class WindowViewHost<View: UIKitViewControllable>: ViewHost {
    public let window: UIWindow

    public init(window: UIWindow) {
        self.window = window
    }

    public func show(_ view: View) {
        window.rootViewController = view.uiviewController
        window.makeKeyAndVisible()
    }

    /// 지금 루트가 `view`일 때만 뗀다.
    public func hide(_ view: View) {
        guard window.rootViewController === view.uiviewController else { return }
        window.rootViewController = nil
    }
}
#endif
