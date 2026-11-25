import Foundation
import Testing
import TodoData
import TodoTransport

/// 네트워크 대신 응답을 돌려주는 `URLProtocol`. 핸들러가 전역이라 이 스위트는 차례로 돈다.
private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    enum Reply {
        case response(status: Int, body: Data)
        case failure(URLError.Code)
        /// 응답하지 않는다. 취소를 확인할 때 쓴다.
        case hang
    }

    /// 테스트가 요청 전에 정하고, 요청이 시작된 뒤에는 읽기만 한다.
    nonisolated(unsafe) static var reply: Reply = .hang

    /// `URLSession`의 스레드가 쓰고 테스트가 읽는다.
    private static let lock = NSLock()
    nonisolated(unsafe) private static var recorded: [URLRequest] = []
    nonisolated(unsafe) private static var recordedBodies: [Data] = []
    static var requests: [URLRequest] { lock.withLock { recorded } }
    /// `URLProtocol`에 오는 요청은 본문을 `httpBody` 대신 `httpBodyStream`에 담는다. 읽어서 따로 둔다.
    static var bodies: [Data] { lock.withLock { recordedBodies } }
    static func reset() { lock.withLock { recorded = []; recordedBodies = [] } }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    private static func readBody(of request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }

    override func startLoading() {
        let body = Self.readBody(of: request)
        Self.lock.withLock {
            Self.recorded.append(request)
            Self.recordedBodies.append(body)
        }
        switch Self.reply {
        case .response(let status, let body):
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let code):
            client?.urlProtocol(self, didFailWithError: URLError(code))
        case .hang:
            break
        }
    }

    override func stopLoading() {}
}

@MainActor
@Suite(.serialized)
struct URLSessionHTTPTransportTests {
    private let transport: URLSessionHTTPTransport

    init() {
        StubURLProtocol.reply = .hang
        StubURLProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        transport = URLSessionHTTPTransport(
            baseURL: URL(string: "https://example.test/api")!,
            session: URLSession(configuration: configuration)
        )
    }

    private func send() async -> Result<HTTPResponse, HTTPTransportError> {
        do throws(HTTPTransportError) {
            return .success(try await transport.send(HTTPRequest(method: .get, path: "/todos")))
        } catch {
            return .failure(error)
        }
    }

    @Test func sendsMethodAndPathUnderBaseURL() async {
        StubURLProtocol.reply = .response(status: 200, body: Data("[]".utf8))

        _ = await send()

        #expect(StubURLProtocol.requests.map(\.url?.absoluteString) == ["https://example.test/api/todos"])
        #expect(StubURLProtocol.requests.first?.httpMethod == "GET")
    }

    @Test func sendsHeadersAndBody() async throws {
        StubURLProtocol.reply = .response(status: 201, body: Data("{}".utf8))
        let request = HTTPRequest(
            method: .post,
            path: "/todos",
            headers: ["Authorization": "Bearer abc", "Content-Type": "application/json"],
            body: #"{"title":"운동"}"#
        )

        _ = try await transport.send(request)

        let sent = try #require(StubURLProtocol.requests.first)
        #expect(sent.httpMethod == "POST")
        #expect(sent.value(forHTTPHeaderField: "Authorization") == "Bearer abc")
        #expect(sent.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(StubURLProtocol.bodies.first == Data(#"{"title":"운동"}"#.utf8))
    }

    @Test func patchSendsMethodAndBody() async throws {
        StubURLProtocol.reply = .response(status: 200, body: Data("{}".utf8))

        _ = try await transport.send(HTTPRequest(method: .patch, path: "/todos/7", body: #"{"done":true}"#))

        #expect(StubURLProtocol.requests.first?.httpMethod == "PATCH")
        #expect(StubURLProtocol.requests.first?.url?.absoluteString == "https://example.test/api/todos/7")
        #expect(StubURLProtocol.bodies.first == Data(#"{"done":true}"#.utf8))
    }

    @Test func deleteWithoutBodySendsNoBody() async throws {
        StubURLProtocol.reply = .response(status: 204, body: Data())

        let response = try await transport.send(HTTPRequest(method: .delete, path: "/todos/7"))

        #expect(response.status == 204)
        #expect(StubURLProtocol.requests.first?.httpMethod == "DELETE")
        #expect(StubURLProtocol.bodies.first == Data())
    }

    @Test func returnsStatusAndBodyBytes() async {
        StubURLProtocol.reply = .response(status: 200, body: Data(#"[{"id":1}]"#.utf8))

        #expect(await send() == .success(HTTPResponse(status: 200, body: Array(#"[{"id":1}]"#.utf8))))
    }

    /// 오류 상태 코드도 응답이다. 해석은 `TodoAPIClient`가 한다.
    @Test func errorStatusIsStillAResponse() async {
        StubURLProtocol.reply = .response(status: 503, body: Data())

        #expect(await send() == .success(HTTPResponse(status: 503, body: [])))
    }

    @Test(arguments: [URLError.Code.notConnectedToInternet, .timedOut, .cannotFindHost])
    func connectionFailureIsUnreachable(code: URLError.Code) async {
        StubURLProtocol.reply = .failure(code)

        #expect(await send() == .failure(.unreachable))
    }

    @Test func cancellingTheTaskCancelsTheRequest() async {
        StubURLProtocol.reply = .hang
        let task = Task { await send() }
        while StubURLProtocol.requests.isEmpty { await Task.yield() }

        task.cancel()

        #expect(await task.value == .failure(.cancelled))
    }
}
