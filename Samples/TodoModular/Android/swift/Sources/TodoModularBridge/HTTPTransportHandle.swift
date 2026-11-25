import TodoModularAndroid

/// Kotlin이 구현한다(`:bridge`의 `HttpUrlConnectionTransport`). 요청을 플랫폼 HTTP 스택으로 보낸다.
/// 결과는 메인 스레드에서 `HTTPTransportHandle.complete`나 `fail`로 돌려준다.
public protocol HTTPTransportBridge {
    /// `headers`는 `이름: 값` 줄을 `\n`으로 끝낸 문자열이고, `body`는 본문이 없으면 빈 문자열이다.
    func start(requestID: Int64, method: String, path: String, headers: String, body: String)
    func cancel(requestID: Int64)
}

/// Kotlin이 전송 계층을 넣고 결과를 돌려주는 통로. 모든 메서드는 메인 스레드에서 부른다.
/// `install`은 `SwiftBridge.start` 전에 부른다. 넣지 않으면 앱 안의 샘플 서버를 쓴다.
public final class HTTPTransportHandle: Sendable {
    public init() {}

    public func install(bridge: any HTTPTransportBridge) {
        nonisolated(unsafe) let bridge = bridge
        MainActor.assumeIsolated {
            precondition(controller == nil, "HTTPTransportHandle.install must be called before SwiftBridge.start")
            httpTransport = AndroidHTTPTransport(sender: BridgeSender(bridge: bridge))
        }
    }

    public func uninstall() {
        MainActor.assumeIsolated { httpTransport = nil }
    }

    /// 응답을 받았다. 상태 코드가 오류여도 이쪽으로 온다.
    public func complete(requestID: Int64, status: Int32, body: String) {
        MainActor.assumeIsolated { httpTransport?.complete(requestID: requestID, status: Int(status), body: body) }
    }

    /// 응답을 받지 못했다(연결 실패, 시간 초과).
    public func fail(requestID: Int64) {
        MainActor.assumeIsolated { httpTransport?.fail(requestID: requestID) }
    }
}

@MainActor
private final class BridgeSender: AndroidHTTPSender {
    private let bridge: any HTTPTransportBridge

    init(bridge: any HTTPTransportBridge) {
        self.bridge = bridge
    }

    func start(requestID: Int64, method: String, path: String, headers: String, body: String) {
        bridge.start(requestID: requestID, method: method, path: path, headers: headers, body: body)
    }

    func cancel(requestID: Int64) {
        bridge.cancel(requestID: requestID)
    }
}
