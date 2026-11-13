#if canImport(UIKit)
import RIBs
import RIBsUIKit
import Testing
import UIKit

@MainActor
struct RIBsUIKitTests {
    private final class Screen: UIViewController, UIKitViewControllable {}

    @Test func uiviewControllerOfOpaqueViewIsTheController() {
        let screen = Screen()
        let opaque: any ViewControllable = screen

        #expect(opaque.uiviewController === screen)
    }

    @Test func containerSwapsChildControllers() {
        let container = RIBContainerViewController()
        let first = Screen()
        let second = Screen()

        container.showScreen(first)
        container.showScreen(second)

        #expect(container.children == [second])
        #expect(first.parent == nil)
        #expect(second.view.superview === container.view)

        container.hideScreen(first)
        #expect(container.currentScreen === second)

        container.hideScreen(second)
        #expect(container.children.isEmpty)
        #expect(container.currentScreen == nil)
    }

    @Test func windowHostDrivesLaunchRouter() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let host = WindowViewHost<Screen>(window: window)
        let root = LaunchRouter(interactor: Interactor(), viewController: Screen())

        root.launch(from: host)
        #expect(window.rootViewController === root.viewController)

        root.shutdown()
        #expect(window.rootViewController == nil)
    }
}
#endif
