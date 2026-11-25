import Testing
import TodoCoreTesting
import TodoData
import TodoModularAndroid

@MainActor
private final class FakeSender: AndroidHTTPSender {
    struct Started: Equatable {
        let requestID: Int64
        let method: String
        let path: String
        let headers: String
        let body: String
    }

    private(set) var started: [Started] = []
    private(set) var cancelled: [Int64] = []

    func start(requestID: Int64, method: String, path: String, headers: String, body: String) {
        started.append(Started(requestID: requestID, method: method, path: path, headers: headers, body: body))
    }

    func cancel(requestID: Int64) { cancelled.append(requestID) }
}

/// Kotlin이 요청을 보내고 나중에 결과를 돌려주는 전송 계층(ADR-0033). 여기서는 Kotlin 자리에 가짜를 둔다.
@MainActor
struct AndroidHTTPTransportTests {
    private let sender = FakeSender()
    private let transport: AndroidHTTPTransport

    init() {
        transport = AndroidHTTPTransport(sender: sender)
    }

    private func send() -> Task<Result<HTTPResponse, HTTPTransportError>, Never> {
        Task { [transport] in
            do throws(HTTPTransportError) {
                return .success(try await transport.send(HTTPRequest(method: .get, path: "/todos")))
            } catch {
                return .failure(error)
            }
        }
    }

    @Test func startsRequestAndReturnsCompletedResponse() async throws {
        let task = send()
        await runCurrent()
        let started = try #require(sender.started.first)
        #expect(started.method == "GET")
        #expect(started.path == "/todos")

        transport.complete(requestID: started.requestID, status: 200, body: "[]")

        #expect(await task.value == .success(HTTPResponse(status: 200, body: Array("[]".utf8))))
    }

    /// swift-java 경계는 문자열만 넘긴다(ADR-0020). 헤더는 이름순 `이름: 값` 줄로, 본문이 없으면 빈 문자열로 보낸다.
    @Test func passesHeadersAsLinesAndBodyAsString() async throws {
        let request = HTTPRequest(
            method: .post,
            path: "/todos",
            headers: ["Content-Type": "application/json", "Authorization": "Bearer abc"],
            body: #"{"title":"운동"}"#
        )
        _ = Task { [transport] in try await transport.send(request) }
        await runCurrent()

        let started = try #require(sender.started.first)
        #expect(started.method == "POST")
        #expect(started.headers == "Authorization: Bearer abc\nContent-Type: application/json\n")
        #expect(started.body == #"{"title":"운동"}"#)
    }

    @Test func requestWithoutHeadersOrBodyPassesEmptyStrings() async throws {
        _ = send()
        await runCurrent()

        let started = try #require(sender.started.first)
        #expect(started.headers == "")
        #expect(started.body == "")
    }

    @Test func failureIsUnreachable() async throws {
        let task = send()
        await runCurrent()

        transport.fail(requestID: try #require(sender.started.first).requestID)

        #expect(await task.value == .failure(.unreachable))
    }

    @Test func concurrentRequestsGetTheirOwnResponses() async throws {
        let first = send()
        await runCurrent()
        let second = send()
        await runCurrent()
        let ids = sender.started.map(\.requestID)
        try #require(ids.count == 2 && ids[0] != ids[1])

        transport.complete(requestID: ids[1], status: 404, body: "")
        transport.complete(requestID: ids[0], status: 200, body: "a")

        #expect(await first.value == .success(HTTPResponse(status: 200, body: Array("a".utf8))))
        #expect(await second.value == .success(HTTPResponse(status: 404, body: [])))
    }

    @Test func cancellingTheTaskCancelsTheRequestAndIgnoresALateResult() async throws {
        let task = send()
        await runCurrent()
        let id = try #require(sender.started.first).requestID

        task.cancel()

        #expect(await task.value == .failure(.cancelled))
        #expect(sender.cancelled == [id])
        // 이미 끝난 요청의 결과가 뒤늦게 와도 아무 일도 일어나지 않는다.
        transport.complete(requestID: id, status: 200, body: "[]")
        transport.fail(requestID: id)
    }
}
