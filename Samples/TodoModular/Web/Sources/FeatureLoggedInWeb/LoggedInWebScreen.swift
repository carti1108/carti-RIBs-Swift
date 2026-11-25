import FeatureLoggedInInterface
import JavaScriptKit
import RIBs
import RIBsWeb
import TodoWebSupport

/// 로그인 피처의 웹 화면을 만든다. 자식 화면은 `content` 자리에만 넣어 자식 피처를 모른다. 화면을 그리는 JS 뷰는 조립 쪽이 `mount`에서 붙인다.
@MainActor
public final class LoggedInWebViewFactory: LoggedInViewFactory {
    private let mount: @MainActor (LoggedInWebScreen) -> Void

    public init(mount: @escaping @MainActor (LoggedInWebScreen) -> Void) {
        self.mount = mount
    }

    public func makeLoggedInView() -> any LoggedInViewContract {
        let screen = LoggedInWebScreen()
        mount(screen)
        return screen
    }
}

@MainActor
public final class LoggedInWebScreen: WebScreen<LoggedInViewState>, LoggedInViewContract {
    public weak var listener: (any LoggedInPresentableListener)?
    /// 자식 화면(할 일 목록·상세)이 들어갈 자리. JS 뷰가 원하는 위치에 넣는다.
    public let content: JSObject
    private let slot = WebScreenSlot()
    private let renderer: SlotRenderer

    init() {
        content = DOMBuilder.element("div", id: "loggedInContent")
        renderer = SlotRenderer(slot: slot, container: content)
        super.init(tag: "section", id: "loggedIn", initialState: LoggedInViewState(userName: ""))
    }

    public func render(_ state: LoggedInViewState) { setViewState(state) }

    public func send(_ action: LoggedInViewAction) { listener?.handle(action) }

    public func showScreen(_ screen: any ViewControllable) { slot.show(screen) }
    public func hideScreen(_ screen: any ViewControllable) { slot.hide(screen) }
}
