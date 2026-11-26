import Foundation
import Network
import Testing
import TodoData
import TodoTransport

/// 테스트 프로세스 안에서 도는 HTTP 서버. 요청 줄·헤더·본문(`Content-Length`만큼)을 기록하고 정한 상태와 본문으로 답한다.
/// `URLProtocol` 가짜와 달리 `URLSession`이 실제 소켓으로 보낸 바이트를 받는다(ADR-0034).
private final class LoopbackServer: @unchecked Sendable {
    struct Request: Equatable {
        let method: String
        let path: String
        /// 이름은 소문자로 둔다.
        let headers: [String: String]
        let body: Data
    }

    private let listener: NWListener
    private let queue = DispatchQueue(label: "LoopbackServer")
    private let status: Int
    private let responseBody: Data
    /// 서버 큐가 쓰고 테스트가 읽는다.
    private let lock = NSLock()
    private var recorded: [Request] = []

    var requests: [Request] { lock.withLock { recorded } }

    init(status: Int, body: String = "") throws {
        let parameters = NWParameters.tcp
        parameters.requiredInterfaceType = .loopback
        listener = try NWListener(using: parameters)
        self.status = status
        responseBody = Data(body.utf8)
    }

    /// 리스너가 포트를 받으면 `http://127.0.0.1:<포트>/api`를 돌려준다.
    func start() async throws -> URL {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, any Error>) in
            listener.stateUpdateHandler = { [listener] state in
                switch state {
                case .ready:
                    listener.stateUpdateHandler = nil
                    continuation.resume(returning: URL(string: "http://127.0.0.1:\(listener.port!.rawValue)/api")!)
                case .failed(let error):
                    listener.stateUpdateHandler = nil
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            listener.newConnectionHandler = { [self] connection in
                connection.start(queue: queue)
                receive(on: connection, buffer: Data())
            }
            listener.start(queue: queue)
        }
    }

    func stop() { listener.cancel() }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [self] data, _, isComplete, error in
            let buffer = buffer + (data ?? Data())
            if let request = Self.parse(buffer) {
                lock.withLock { recorded.append(request) }
                reply(on: connection)
            } else if isComplete || error != nil {
                connection.cancel()
            } else {
                receive(on: connection, buffer: buffer)
            }
        }
    }

    /// 헤더 끝과 `Content-Length`만큼의 본문이 모두 왔으면 요청을, 아니면 nil을 돌려준다.
    private static func parse(_ buffer: Data) -> Request? {
        guard let headerEnd = buffer.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let lines = String(decoding: buffer[..<headerEnd.lowerBound], as: UTF8.self).components(separatedBy: "\r\n")
        let requestLine = lines[0].split(separator: " ")
        guard requestLine.count >= 2 else { return nil }
        let headers = Dictionary(
            lines.dropFirst().compactMap { line -> (String, String)? in
                guard let separator = line.range(of: ": ") else { return nil }
                return (line[..<separator.lowerBound].lowercased(), String(line[separator.upperBound...]))
            },
            uniquingKeysWith: { _, last in last }
        )
        let length = Int(headers["content-length"] ?? "") ?? 0
        let body = buffer[headerEnd.upperBound...]
        guard body.count >= length else { return nil }
        return Request(
            method: String(requestLine[0]),
            path: String(requestLine[1]),
            headers: headers,
            body: Data(body.prefix(length))
        )
    }

    private func reply(on connection: NWConnection) {
        let head = "HTTP/1.1 \(status) Test\r\nContent-Type: application/json\r\n"
            + "Content-Length: \(responseBody.count)\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(head.utf8) + responseBody, completion: .contentProcessed { _ in connection.cancel() })
    }
}

/// `URLSessionHTTPTransport`가 실제 소켓으로 메서드·헤더·본문을 보내는지, 공유 클라이언트까지 이어 확인한다.
@MainActor
struct URLSessionHTTPTransportLoopbackTests {
    private func transport(_ baseURL: URL) -> URLSessionHTTPTransport {
        URLSessionHTTPTransport(baseURL: baseURL, session: URLSession(configuration: .ephemeral))
    }

    @Test func createTodoSendsBearerTokenAndUtf8JsonBody() async throws {
        let server = try LoopbackServer(status: 201, body: #"{"id":7,"title":"운동","done":false}"#)
        defer { server.stop() }
        let baseURL = try await server.start()
        let client = TodoAPIClient(transport: BearerTokenTransport(base: transport(baseURL), token: { "abc" }))

        let todo = try await client.createTodo(title: "운동")

        #expect(todo.id == 7)
        #expect(todo.title == "운동")
        let sent = try #require(server.requests.first)
        #expect(sent.method == "POST")
        #expect(sent.path == "/api/todos")
        #expect(sent.headers["authorization"] == "Bearer abc")
        #expect(sent.headers["content-type"] == "application/json")
        #expect(sent.body == Data(#"{"title":"운동"}"#.utf8))
    }

    @Test func unauthorizedReplyIsReadAsProblemDetails() async throws {
        let server = try LoopbackServer(status: 401, body: #"{"title":"토큰 만료","status":401}"#)
        defer { server.stop() }
        let baseURL = try await server.start()
        let client = TodoAPIClient(transport: transport(baseURL))

        await #expect(throws: TodoAPIError.unauthorized(problem: ProblemDetails(title: "토큰 만료", status: 401))) {
            _ = try await client.createTodo(title: "운동")
        }
        #expect(server.requests.first?.headers["authorization"] == nil)
    }

    @Test func patchIsSentWithBody() async throws {
        let server = try LoopbackServer(status: 200, body: "{}")
        defer { server.stop() }
        let baseURL = try await server.start()

        let response = try await transport(baseURL).send(HTTPRequest(method: .patch, path: "/todos/7", body: #"{"done":true}"#))

        #expect(response.status == 200)
        let sent = try #require(server.requests.first)
        #expect(sent.method == "PATCH")
        #expect(sent.path == "/api/todos/7")
        #expect(sent.body == Data(#"{"done":true}"#.utf8))
    }

    @Test func deleteWithoutBodySendsNoBody() async throws {
        let server = try LoopbackServer(status: 204)
        defer { server.stop() }
        let baseURL = try await server.start()

        let response = try await transport(baseURL).send(HTTPRequest(method: .delete, path: "/todos/7"))

        #expect(response.status == 204)
        let sent = try #require(server.requests.first)
        #expect(sent.method == "DELETE")
        #expect(sent.headers["content-length"] ?? "0" == "0")
        #expect(sent.body.isEmpty)
    }
}
