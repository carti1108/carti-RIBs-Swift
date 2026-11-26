import Foundation
import TodoData

/// `URLSession`으로 보내는 전송 계층(ADR-0033). 요청을 보내고 상태 코드와 본문을 그대로 돌려준다.
@MainActor
public final class URLSessionHTTPTransport: HTTPTransport {
    private let baseURL: URL
    private let session: URLSession

    /// `baseURL`은 요청 경로 앞에 붙는다(`https://example.com/api` + `/todos`).
    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    public func send(_ request: HTTPRequest) async throws(HTTPTransportError) -> HTTPResponse {
        var urlRequest = URLRequest(url: baseURL.appending(path: request.path))
        urlRequest.httpMethod = request.method.rawValue
        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }
        urlRequest.httpBody = request.body.map { Data($0.utf8) }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            // Task가 취소되면 `URLSession`이 요청을 끊고 `URLError.cancelled`를 던진다.
            throw Task.isCancelled || (error as? URLError)?.code == .cancelled ? .cancelled : .unreachable
        }
        guard let http = response as? HTTPURLResponse else { throw .unreachable }
        return HTTPResponse(status: http.statusCode, body: Array(data))
    }
}
