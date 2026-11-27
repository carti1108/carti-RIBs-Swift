import JavaScriptKit

/// 앱 전체가 공유하는 단일 채널 브리지(ADR-0022 확장).
/// 피처마다 `@JS` 프로토콜과 핸들을 만들지 않고, 상태/액션 JSON 문자열로 주고받는다.
/// BridgeJS의 `JSObject?` 전달 제약을 피하기 위해 자식 슬롯은 `setContent`로 분리한다.
@JS protocol ChannelViewBridge {
    func mount(host: JSObject, handle: ChannelHandle)
    func setContent(content: JSObject)
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
