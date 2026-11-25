/// 데이터 계층이 쓰는 요청. 값 타입이라 테스트가 통째로 비교한다.
public struct HTTPRequest: Equatable, Sendable {
    public enum Method: String, Equatable, Sendable {
        case get = "GET"
    }

    public let method: Method
    /// 서버 주소를 뺀 경로(`/todos`). 주소는 플랫폼의 전송 구현이 붙인다.
    public let path: String

    public init(method: Method, path: String) {
        self.method = method
        self.path = path
    }
}

/// 본문은 바이트 배열이다. `Data`를 쓰지 않아 플랫폼의 전송 구현이 Foundation 없이도 만들 수 있다.
public struct HTTPResponse: Equatable, Sendable {
    public let status: Int
    public let body: [UInt8]

    public init(status: Int, body: [UInt8]) {
        self.status = status
        self.body = body
    }
}

public enum HTTPTransportError: Error, Equatable, Sendable {
    /// 부른 Task가 취소됐다.
    case cancelled
    /// 응답을 받지 못했다(연결 실패, 시간 초과).
    case unreachable
}

/// 요청을 보내고 응답을 받는 일만 한다. 플랫폼이 구현하는 것은 이 프로토콜 하나다(iOS `URLSession`, Web `fetch`).
/// 상태 코드가 오류여도 응답을 받았으면 던지지 않는다. 해석은 `TodoAPIClient`가 한다.
@MainActor
public protocol HTTPTransport: AnyObject {
    func send(_ request: HTTPRequest) async throws(HTTPTransportError) -> HTTPResponse
}
