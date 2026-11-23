import JavaScriptKit
import RIBs
import RIBsWeb

/// 루트 화면. 자식 RIB 화면 하나를 담는다. 그릴 것이 없어 JS 뷰를 두지 않는다.
/// 데모 페이지에서는 부모 대신 받은 이벤트를 `#demoEvent`에 보여 준다.
@MainActor
public final class HostRootScreen: DOMScreen {
    public let element: JSObject
    private let eventLabel: JSObject
    private let slot = WebScreenSlot()
    private let renderer: SlotRenderer

    public init() {
        element = DOMBuilder.element("div", id: "root")
        let content = DOMBuilder.element("div", id: "rootContent")
        eventLabel = DOMBuilder.element("p", id: "demoEvent")
        eventLabel.hidden = .boolean(true)
        _ = element.append!(content, eventLabel)
        renderer = SlotRenderer(slot: slot, container: content)
    }

    public func showScreen(_ screen: any ViewControllable) { slot.show(screen) }
    public func hideScreen(_ screen: any ViewControllable) { slot.hide(screen) }

    public func showEvent(_ event: String) {
        eventLabel.textContent = .string(event)
        eventLabel.hidden = .boolean(false)
    }
}

/// 데모 페이지에서 자식 피처 대신 붙이는 화면. 제목과 버튼 하나만 있다.
/// 피처의 뷰가 아니라 데모용 발판이라 JS 뷰 없이 Swift가 직접 그린다.
@MainActor
public final class PlaceholderScreen: DOMScreen {
    public let element: JSObject
    private let onClick: JSClosure

    public init(title: String, actionTitle: String, action: @escaping @MainActor () -> Void) {
        element = DOMBuilder.element("section", id: "placeholder")
        let button = DOMBuilder.element("button", id: "placeholderAction", text: actionTitle)
        onClick = JSClosure { _ in
            MainActor.assumeIsolated { action() }
            return .undefined
        }
        _ = button.addEventListener!("click", onClick)
        _ = element.append!(DOMBuilder.element("p", id: "placeholderTitle", text: title), button)
    }
}
