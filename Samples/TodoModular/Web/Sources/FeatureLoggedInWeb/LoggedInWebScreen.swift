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

/// 상세는 `content` 자리에서 목록을 가리고, 브라우저 기록 항목 하나를 차지한다.
/// 브라우저가 그 항목을 벗어나면 상세를 먼저 떼고 공유 코드에 알린다(ADR-0030).
///
/// 기록은 이 화면보다 오래 남는다(새로고침, 로그아웃 뒤 재로그인, 앞으로 가기). 그래서 "지금 상세의 항목인가"는
/// `history.state`가 이 상세에 준 토큰과 같은지로만 판단한다. `history.back()`은 부르지 않는다. 비동기라 그 사이 열린 상세와 엇갈린다.
@MainActor
public final class LoggedInWebScreen: WebScreen<LoggedInViewState>, LoggedInViewContract {
    private static let tokenPrefix = "ribsDetail:"

    public weak var listener: (any LoggedInPresentableListener)?
    /// 자식 화면(할 일 목록·상세)이 들어갈 자리. JS 뷰가 원하는 위치에 넣는다.
    public let content: JSObject
    private let slot = WebScreenSlot()
    private let renderer: SlotRenderer
    private var list: (any ViewControllable)?
    private var detail: (any ViewControllable)?
    /// 지금 열린 상세가 차지한 기록 항목의 `history.state`.
    private var detailToken: String?
    private var onPopState: JSClosure?

    init() {
        content = DOMBuilder.element("div", id: "loggedInContent")
        renderer = SlotRenderer(slot: slot, container: content)
        super.init(tag: "section", id: "loggedIn", initialState: LoggedInViewState(userName: ""))
        let onPopState = JSClosure { [weak self] _ in
            MainActor.assumeIsolated { self?.browserDidGoBack() }
            return .undefined
        }
        _ = JSObject.global.addEventListener!("popstate", onPopState)
        self.onPopState = onPopState
    }

    isolated deinit {
        if let onPopState {
            _ = JSObject.global.removeEventListener!("popstate", onPopState)
        }
    }

    public func render(_ state: LoggedInViewState) { setViewState(state) }

    public func send(_ action: LoggedInViewAction) { listener?.handle(action) }

    public func showList(_ screen: any ViewControllable) {
        list = screen
        if detail == nil { slot.show(screen) }
    }

    public func showDetail(_ screen: any ViewControllable) {
        detail = screen
        slot.show(screen)
        let token = Self.tokenPrefix + String(UInt64.random(in: .min ... .max))
        detailToken = token
        // 닫힌 상세가 남긴 항목 위에 있으면 그 항목을 다시 쓴다. 아니면 항목을 더한다.
        if Self.isOnLeftoverEntry {
            _ = Self.history.replaceState!(token, "")
        } else {
            _ = Self.history.pushState!(token, "")
        }
    }

    public func hideDetail(_ screen: any ViewControllable) {
        guard detail === screen else { return }
        // Router가 닫았다. 기록 항목은 그대로 두고, 다음 상세가 다시 쓴다.
        removeDetail()
    }

    private func browserDidGoBack() {
        guard detail != nil, Self.history.state.string != detailToken else { return }
        removeDetail()
        send(.detailDismissedByUser)
    }

    private func removeDetail() {
        detail = nil
        detailToken = nil
        if let list { slot.show(list) }
    }

    private static var history: JSObject { JSObject.global.history.object! }
    private static var isOnLeftoverEntry: Bool { history.state.string?.hasPrefix(tokenPrefix) ?? false }
}
