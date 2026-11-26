/// 데이터 계층이 쓰는 요청. 값 타입이라 테스트가 통째로 비교한다.
public struct HTTPRequest: Equatable, Sendable {
    public enum Method: String, Equatable, Sendable {
        case get = "GET"
        case post = "POST"
        case patch = "PATCH"
        case delete = "DELETE"
    }

    public let method: Method
    /// 서버 주소를 뺀 경로(`/todos`). 주소는 플랫폼의 전송 구현이 붙인다.
    public let path: String
    /// 이름은 대소문자를 가리지 않는다는 HTTP 규칙을 따로 처리하지 않는다. 공유 코드는 표준 표기(`Content-Type`)로 넣는다.
    public let headers: [String: String]
    /// UTF-8 텍스트(JSON)만 싣는다. Android·Web 전송이 경계에서 문자열로 넘기기 때문이다(ADR-0033).
    /// Android 전송은 빈 문자열을 본문 없음으로 보낸다. 빈 본문을 보내야 하면 nil과 구분되지 않는다(ADR-0034).
    public let body: String?

    public init(method: Method, path: String, headers: [String: String] = [:], body: String? = nil) {
        self.method = method
        self.path = path
        self.headers = headers
        self.body = body
    }

    /// 헤더 하나를 더하거나 바꾼 새 요청.
    public func setting(header name: String, to value: String) -> HTTPRequest {
        var headers = headers
        headers[name] = value
        return HTTPRequest(method: method, path: path, headers: headers, body: body)
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
    /// 브라우저에서는 CORS 거부도 여기에 든다. `fetch`가 둘을 같은 네트워크 오류로 알려 구분할 수 없다.
    case unreachable
}

/// 요청을 보내고 응답을 받는 일만 한다. 플랫폼이 구현하는 것은 이 프로토콜 하나다(iOS `URLSession`, Web `fetch`).
/// 메서드·헤더·본문을 받은 그대로 보낸다. 상태 코드가 오류여도 응답을 받았으면 던지지 않는다. 해석은 `TodoAPIClient`가 한다.
@MainActor
public protocol HTTPTransport: AnyObject {
    func send(_ request: HTTPRequest) async throws(HTTPTransportError) -> HTTPResponse
}
