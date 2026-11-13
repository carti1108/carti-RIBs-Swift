#if canImport(UIKit)
import RIBs
import UIKit

/// UIKit 화면을 가진 RIB 뷰. RIBs-iOS `ViewControllable.uiviewController`.
@MainActor
public protocol UIKitViewControllable: ViewControllable {
    var uiviewController: UIViewController { get }
}

extension UIKitViewControllable where Self: UIViewController {
    public var uiviewController: UIViewController { self }
}

extension ViewControllable {
    /// 공유 코드가 넘긴 불투명한 뷰의 `UIViewController`. UIKit 뷰가 아니면 계약 위반으로 실패한다.
    public var uiviewController: UIViewController {
        guard let controllable = self as? any UIKitViewControllable else {
            preconditionFailure("\(type(of: self)) should conform to \((any UIKitViewControllable).self)")
        }
        return controllable.uiviewController
    }
}
#endif
