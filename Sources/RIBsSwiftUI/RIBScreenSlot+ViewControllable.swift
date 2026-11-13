#if canImport(SwiftUI)
import RIBs

extension RIBScreenSlot {
    /// 공유 코드가 넘긴 불투명한 뷰를 보여 준다. SwiftUI로 그릴 수 없는 뷰면 계약 위반으로 실패한다.
    public func show(_ screen: any ViewControllable) {
        show(Self.renderable(screen))
    }

    public func hide(_ screen: any ViewControllable) {
        hide(Self.renderable(screen))
    }

    private static func renderable(_ screen: any ViewControllable) -> any SwiftUIRenderable {
        guard let renderable = screen as? any SwiftUIRenderable else {
            preconditionFailure("\(type(of: screen)) should conform to \((any SwiftUIRenderable).self)")
        }
        return renderable
    }
}
#endif
