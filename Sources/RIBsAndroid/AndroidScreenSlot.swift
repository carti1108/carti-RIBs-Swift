import RIBs

/// 자식 RIB 화면 하나를 담는 자리. `RIBScreenSlot`(SwiftUI)과 같은 규칙: `hide`는 지금 보이는 화면일 때만 비운다.
@MainActor
public final class AndroidScreenSlot {
    public private(set) var current: AndroidScreen?
    private unowned let owner: AndroidScreen

    /// `owner`는 슬롯을 가진 화면이다. 내용이 바뀌면 owner가 다시 그려진다.
    public init(owner: AndroidScreen) {
        self.owner = owner
    }

    public func show(_ screen: any ViewControllable) {
        current = Self.androidScreen(screen)
        owner.setNeedsRender()
    }

    public func hide(_ screen: any ViewControllable) {
        guard current === Self.androidScreen(screen) else { return }
        current = nil
        owner.setNeedsRender()
    }

    /// 상태에 넣을 값. 비어 있으면 `.null`.
    public var renderedValue: RibValue {
        current.map { .state($0.renderTree()) } ?? .null
    }

    private static func androidScreen(_ screen: any ViewControllable) -> AndroidScreen {
        guard let androidScreen = screen as? AndroidScreen else {
            preconditionFailure("\(type(of: screen)) should inherit \(AndroidScreen.self)")
        }
        return androidScreen
    }
}
