import JavaScriptKit

/// 앱 전체가 공유하는 단일 채널 브리지(ADR-0022 확장).
/// 피처마다 `@JS` 프로토콜과 핸들을 만들지 않고, 상태/액션 JSON 문자열로 주고받는다.
@JS protocol ChannelViewBridge {
    func mount(host: JSObject, content: JSObject?, handle: ChannelHandle)
    func render(stateJSON: String)
}

@JS final class ChannelHandle: Sendable {
    private let onDispatch: @MainActor @Sendable (String) -> Void

    init(onDispatch: @escaping @MainActor @Sendable (String) -> Void) {
        self.onDispatch = onDispatch
    }

    @JS func dispatch(actionJSON: String) {
        MainActor.assumeIsolated { onDispatch(actionJSON) }
    }
}
