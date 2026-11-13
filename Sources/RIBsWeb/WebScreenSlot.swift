import RIBs

/// 자식 RIB 화면 하나를 담는 자리. 브라우저 쪽 렌더러가 `observe`로 구독해 바뀐 화면을 DOM에 붙인다.
///
/// `RIBsSwiftUI.RIBScreenSlot`, carti-RIBs-KMP `ScreenSlot`과 같은 역할이다(ADR-0009).
/// DOM이나 JavaScriptKit에 의존하지 않으므로 호스트(macOS·Linux)에서도 빌드하고 테스트한다.
@MainActor
public final class WebScreenSlot {
    public typealias ChangeHandler = @MainActor ((any ViewControllable)?) -> Void

    public private(set) var current: (any ViewControllable)?
    private var handlers: [UInt64: ChangeHandler] = [:]
    private var nextHandlerID: UInt64 = 0

    public init() {}

    /// 같은 화면을 다시 보이면 아무 일도 하지 않는다.
    public func show(_ screen: any ViewControllable) {
        guard current !== screen else { return }
        current = screen
        notify()
    }

    /// 지금 보이는 화면일 때만 비운다. 이미 다른 화면으로 바뀌었다면 무시한다.
    public func hide(_ screen: any ViewControllable) {
        guard current === screen else { return }
        current = nil
        notify()
    }

    /// 현재 화면을 바로 한 번 넘기고, 바뀔 때마다 다시 넘긴다. 돌려받은 구독을 `cancel`하면 멈춘다.
    public func observe(_ handler: @escaping ChangeHandler) -> WebSlotSubscription {
        let id = nextHandlerID
        nextHandlerID += 1
        handlers[id] = handler
        handler(current)
        return WebSlotSubscription { [weak self] in self?.handlers[id] = nil }
    }

    private func notify() {
        let screen = current
        handlers.values.forEach { $0(screen) }
    }
}

/// `WebScreenSlot.observe`의 구독. 렌더러가 화면을 버릴 때 `cancel`한다.
@MainActor
public final class WebSlotSubscription {
    private var onCancel: (@MainActor () -> Void)?

    init(onCancel: @escaping @MainActor () -> Void) {
        self.onCancel = onCancel
    }

    public func cancel() {
        onCancel?()
        onCancel = nil
    }
}

/// 루트 RIB 화면을 브라우저 문서에 붙이는 `ViewHost`. 진입점은 `slot`을 구독해 루트 화면을 그린다.
@MainActor
public final class WebViewHost<View: ViewControllable>: ViewHost {
    public let slot = WebScreenSlot()

    public init() {}

    public func show(_ view: View) { slot.show(view) }
    public func hide(_ view: View) { slot.hide(view) }
}
