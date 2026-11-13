#if canImport(SwiftUI)
import RIBs
import SwiftUI

/// 루트 RIB 화면을 SwiftUI 창에 붙이는 `ViewHost`. 앱은 `RIBSlotView(slot: host.slot)`을 창의 내용으로 둔다.
@MainActor
public final class SwiftUIViewHost<View: SwiftUIRenderable>: ViewHost {
    public let slot = RIBScreenSlot()

    public init() {}

    public func show(_ view: View) {
        slot.show(view as any SwiftUIRenderable)
    }

    public func hide(_ view: View) {
        slot.hide(view as any SwiftUIRenderable)
    }
}
#endif
