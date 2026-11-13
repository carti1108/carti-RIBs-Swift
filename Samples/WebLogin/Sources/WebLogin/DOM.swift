import JavaScriptKit
import RIBs
import RIBsWeb

/// DOM 요소 하나로 그려지는 RIB 뷰. 부모 화면은 공유 코드가 넘긴 `any ViewControllable`을 이 타입으로 바꿔 붙인다.
@MainActor
protocol DOMScreen: ViewControllable {
    var element: JSObject { get }
}

/// 작은 DOM 헬퍼. 이벤트 클로저는 요소가 살아 있는 동안 Swift 쪽에서 붙잡아 둔다.
@MainActor
final class DOMBuilder {
    private static var document: JSObject { JSObject.global.document.object! }
    private var closures: [JSClosure] = []

    func element(_ tag: String, id: String? = nil, text: String? = nil) -> JSObject {
        let node = Self.document.createElement!(tag).object!
        if let id { node.id = .string(id) }
        if let text { node.textContent = .string(text) }
        return node
    }

    func button(id: String, text: String, onClick: @escaping @MainActor () -> Void) -> JSObject {
        let node = element("button", id: id, text: text)
        let closure = JSClosure { _ in
            MainActor.assumeIsolated { onClick() }
            return .undefined
        }
        closures.append(closure)
        node.onclick = .object(closure)
        return node
    }
}

extension JSObject {
    func append(_ children: JSObject...) {
        children.forEach { _ = self.appendChild!($0) }
    }

    func setText(_ text: String) { self["textContent"] = .string(text) }
    func setHidden(_ hidden: Bool) { self["hidden"] = .boolean(hidden) }
    func setDisabled(_ disabled: Bool) { self["disabled"] = .boolean(disabled) }
}

/// `WebScreenSlot`을 구독해 지금 화면의 요소만 `container` 안에 둔다.
@MainActor
final class SlotRenderer {
    private var subscription: WebSlotSubscription?

    init(slot: WebScreenSlot, container: JSObject) {
        subscription = slot.observe { screen in
            _ = container.replaceChildren!()
            guard let screen else { return }
            guard let domScreen = screen as? any DOMScreen else {
                preconditionFailure("\(type(of: screen)) should conform to \((any DOMScreen).self)")
            }
            _ = container.appendChild!(domScreen.element)
        }
    }

    func stop() {
        subscription?.cancel()
        subscription = nil
    }
}
