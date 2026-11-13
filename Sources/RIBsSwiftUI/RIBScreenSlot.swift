#if canImport(SwiftUI)
// `ViewControllable`을 받는 오버로드는 다른 파일에 있다.
import Observation
import SwiftUI

/// 자식 RIB 화면 하나를 담는 자리. Router가 `show`/`hide`를 부르면 연결된 `RIBSlotView`가 다시 그려진다.
@MainActor
@Observable
public final class RIBScreenSlot {
    public private(set) var current: (any SwiftUIRenderable)?

    public init() {}

    public func show(_ screen: any SwiftUIRenderable) {
        current = screen
    }

    /// 지금 보이는 화면일 때만 비운다. 이미 다른 화면으로 바뀌었다면 무시한다.
    public func hide(_ screen: any SwiftUIRenderable) {
        guard current === screen else { return }
        current = nil
    }
}

/// `RIBScreenSlot`의 현재 화면을 그리는 SwiftUI 뷰. 비어 있으면 아무것도 그리지 않는다.
public struct RIBSlotView: View {
    private let slot: RIBScreenSlot

    public init(slot: RIBScreenSlot) {
        self.slot = slot
    }

    public var body: some View {
        if let screen = slot.current {
            // 같은 타입의 새 RIB 화면으로 바뀌어도 이전 화면의 @State가 남지 않도록 객체마다 정체성을 준다.
            screen.makeView().id(ObjectIdentifier(screen))
        }
    }
}
#endif
