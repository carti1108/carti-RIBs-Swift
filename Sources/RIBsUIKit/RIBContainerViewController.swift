#if canImport(UIKit)
import RIBs
import UIKit

/// 자식 RIB 화면 하나를 child view controller로 담는 컨테이너. SwiftUI 어댑터의 `RIBScreenSlot`에 해당한다.
/// 뷰 계약의 `showScreen`/`hideScreen`을 구현할 때 쓴다.
@MainActor
open class RIBContainerViewController: UIViewController, UIKitViewControllable {
    public private(set) var currentScreen: UIViewController?

    /// 이전 화면을 떼고 `screen`을 꽉 차게 붙인다.
    public func showScreen(_ screen: any ViewControllable) {
        let child = screen.uiviewController
        guard child !== currentScreen else { return }
        currentScreen.map(remove)
        addChild(child)
        child.view.frame = view.bounds
        child.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(child.view)
        child.didMove(toParent: self)
        currentScreen = child
    }

    /// 지금 보이는 화면일 때만 뗀다.
    public func hideScreen(_ screen: any ViewControllable) {
        let child = screen.uiviewController
        guard child === currentScreen else { return }
        remove(child)
        currentScreen = nil
    }

    private func remove(_ child: UIViewController) {
        child.willMove(toParent: nil)
        child.view.removeFromSuperview()
        child.removeFromParent()
    }
}
#endif
