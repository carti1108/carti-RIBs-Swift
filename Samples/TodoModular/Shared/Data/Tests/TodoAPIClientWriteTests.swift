import Testing
import TodoCore
import TodoCoreTesting
import TodoData

@MainActor
struct TodoAPIClientWriteTests {
    private let transport = FakeHTTPTransport()

    private func create(title: String) -> Task<Result<Todo, TodoAPIError>, Never> {
        let client = TodoAPIClient(transport: transport)
        return Task {
            do throws(TodoAPIError) {
                return .success(try await client.createTodo(title: title))
            } catch {
                return .failure(error)
            }
        }
    }

    @Test func createTodoPostsJSONBody() async {
        _ = create(title: "우유 \"사기\"")
        await runCurrent()

        #expect(transport.requests == [HTTPRequest(
            method: .post,
            path: "/todos",
            headers: ["Content-Type": "application/json"],
            body: #"{"title":"우유 \"사기\""}"#
        )])
    }

    @Test func createdTodoIsDecodedFromResponse() async {
        let task = create(title: "운동")
        await runCurrent()

        transport.respond(status: 201, json: #"{"id": 7, "title": "운동", "done": false}"#)

        #expect(await task.value == .success(Todo(id: 7, title: "운동", isDone: false)))
    }

    @Test func unauthorizedCarriesProblemDetails() async {
        let task = create(title: "운동")
        await runCurrent()

        transport.respond(status: 401, json: #"{"type": "https://example.com/probs/token-expired", "title": "토큰 만료", "status": 401, "detail": "다시 로그인하세요", "instance": "/todos"}"#)

        #expect(await task.value == .failure(.unauthorized(problem: ProblemDetails(
            type: "https://example.com/probs/token-expired",
            title: "토큰 만료",
            status: 401,
            detail: "다시 로그인하세요",
            instance: "/todos"
        ))))
    }

    @Test func conflictCarriesProblemDetails() async {
        let task = create(title: "운동")
        await runCurrent()

        transport.respond(status: 409, json: #"{"title": "이미 있는 할 일", "status": 409, "extra": 1}"#)

        #expect(await task.value == .failure(.conflict(problem: ProblemDetails(title: "이미 있는 할 일", status: 409))))
    }

    /// RFC 9457 §3.1: 타입이 틀린 멤버는 없는 것으로 보고 나머지는 읽는다.
    @Test func mistypedMemberIsIgnored() async {
        let task = create(title: "운동")
        await runCurrent()

        transport.respond(status: 401, json: #"{"type": 1, "title": "토큰 만료", "status": "401", "detail": "다시 로그인하세요"}"#)

        #expect(await task.value == .failure(.unauthorized(problem: ProblemDetails(title: "토큰 만료", detail: "다시 로그인하세요"))))
    }

    @Test func missingTypeMeansAboutBlank() {
        #expect(ProblemDetails().type == "about:blank")
    }

    @Test func serverErrorCarriesProblemDetails() async {
        let task = create(title: "운동")
        await runCurrent()

        transport.respond(status: 503, json: #"{"title": "점검 중"}"#)

        #expect(await task.value == .failure(.badStatus(503, problem: ProblemDetails(title: "점검 중"))))
    }

    @Test(arguments: ["", "<html>Bad Gateway</html>", "[]", "\"text\""])
    func nonProblemBodyHasNoProblem(body: String) async {
        let task = create(title: "운동")
        await runCurrent()

        transport.respond(status: 502, json: body)

        #expect(await task.value == .failure(.badStatus(502, problem: nil)))
    }

    @Test func malformedCreatedBodyIsMalformed() async {
        let task = create(title: "운동")
        await runCurrent()

        transport.respond(status: 201, json: "{}")

        #expect(await task.value == .failure(.malformedBody))
    }

    @Test func transportFailureIsUnreachable() async {
        let task = create(title: "운동")
        await runCurrent()

        transport.respond(.failure(.unreachable))

        #expect(await task.value == .failure(.unreachable))
    }

    @Test func fetchTodosAlsoClassifiesUnauthorized() async {
        let client = TodoAPIClient(transport: transport)
        let task = Task { () -> TodoAPIError? in
            do throws(TodoAPIError) { _ = try await client.fetchTodos(); return nil } catch { return error }
        }
        await runCurrent()

        transport.respond(status: 401, json: "")

        #expect(await task.value == .unauthorized(problem: nil))
    }
}

@MainActor
struct BearerTokenTransportTests {
    private let base = FakeHTTPTransport()

    @Test func addsAuthorizationHeaderAndKeepsOtherHeaders() async throws {
        let transport = BearerTokenTransport(base: base, token: { "abc" })
        let request = HTTPRequest(method: .post, path: "/todos", headers: ["Content-Type": "application/json"], body: "{}")

        let task = Task { try await transport.send(request) }
        await runCurrent()
        base.respond(status: 201, json: "{}")

        #expect(try await task.value.status == 201)
        #expect(base.requests == [HTTPRequest(
            method: .post,
            path: "/todos",
            headers: ["Content-Type": "application/json", "Authorization": "Bearer abc"],
            body: "{}"
        )])
    }

    @Test func withoutTokenSendsRequestUnchanged() async {
        let transport = BearerTokenTransport(base: base, token: { nil })

        _ = Task { try await transport.send(HTTPRequest(method: .get, path: "/todos")) }
        await runCurrent()

        #expect(base.requests == [HTTPRequest(method: .get, path: "/todos")])
    }

    @Test func readsTokenForEachRequest() async {
        var token = "first"
        let transport = BearerTokenTransport(base: base, token: { token })

        _ = Task { try await transport.send(HTTPRequest(method: .get, path: "/todos")) }
        await runCurrent()
        base.respond(json: "[]")
        token = "second"
        _ = Task { try await transport.send(HTTPRequest(method: .get, path: "/todos")) }
        await runCurrent()

        #expect(base.requests.map { $0.headers["Authorization"] } == ["Bearer first", "Bearer second"])
    }
}

/// 401 뒤 토큰 갱신과 한 번의 재시도.
@MainActor
final class BearerTokenRefreshTests {
    private let base = FakeHTTPTransport()
    private var token: String? = "old"
    private(set) var refreshes = 0
    /// 갱신이 돌려줄 토큰. nil이면 갱신 실패다.
    private var renewed: String? = "new"
    /// 열려 있지 않으면 갱신이 `open()`까지 기다린다.
    private var gate: CheckedContinuation<Void, Never>?
    private var holdsRefresh = false

    private func makeTransport(refreshing: Bool = true) -> BearerTokenTransport {
        let token: @MainActor () -> String? = { [unowned self] in self.token }
        guard refreshing else { return BearerTokenTransport(base: base, token: token) }
        return BearerTokenTransport(base: base, token: token, refresh: { [unowned self] in await self.refresh() })
    }

    private func refresh() async -> String? {
        refreshes += 1
        if holdsRefresh { await withCheckedContinuation { gate = $0 } }
        token = renewed
        return renewed
    }

    private func open() {
        gate?.resume()
        gate = nil
    }

    private func send(_ transport: BearerTokenTransport) -> Task<Int, any Error> {
        Task { try await transport.send(HTTPRequest(method: .get, path: "/todos")).status }
    }

    private var sentTokens: [String?] { base.requests.map { $0.headers["Authorization"] } }

    @Test func unauthorizedRefreshesAndRetriesOnceWithNewToken() async throws {
        let task = send(makeTransport())
        await runCurrent()

        base.respond(status: 401, json: "{}")
        await runCurrent()
        base.respond(json: "[]")

        #expect(try await task.value == 200)
        #expect(refreshes == 1)
        #expect(sentTokens == ["Bearer old", "Bearer new"])
    }

    @Test func retryRejectedAgainReturns401WithoutSecondRefresh() async throws {
        let task = send(makeTransport())
        await runCurrent()

        base.respond(status: 401, json: "{}")
        await runCurrent()
        base.respond(status: 401, json: "{}")

        #expect(try await task.value == 401)
        #expect(refreshes == 1)
        #expect(base.requests.count == 2)
    }

    @Test func failedRefreshReturnsOriginal401() async throws {
        renewed = nil
        let task = send(makeTransport())
        await runCurrent()

        base.respond(status: 401, json: "{}")

        #expect(try await task.value == 401)
        #expect(refreshes == 1)
        #expect(base.requests.count == 1)
    }

    @Test func withoutRefreshReturns401AsIs() async throws {
        let task = send(makeTransport(refreshing: false))
        await runCurrent()

        base.respond(status: 401, json: "{}")

        #expect(try await task.value == 401)
        #expect(base.requests.count == 1)
    }

    /// 토큰 없이 보낸 요청의 401은 갱신할 토큰이 없다는 뜻이다.
    @Test func requestSentWithoutTokenIsNotRefreshed() async throws {
        token = nil
        let task = send(makeTransport())
        await runCurrent()

        base.respond(status: 401, json: "{}")

        #expect(try await task.value == 401)
        #expect(refreshes == 0)
    }

    @Test func otherErrorStatusIsNotRefreshed() async throws {
        let task = send(makeTransport())
        await runCurrent()

        base.respond(status: 403, json: "{}")

        #expect(try await task.value == 403)
        #expect(refreshes == 0)
    }

    /// 갱신 중에 401을 받은 요청은 새로 갱신하지 않고 진행 중인 갱신을 기다린다.
    @Test func concurrentUnauthorizedRequestsShareOneRefresh() async throws {
        holdsRefresh = true
        let transport = makeTransport()
        let first = send(transport)
        let second = send(transport)
        await runCurrent()

        base.respond(status: 401, json: "{}")
        base.respond(status: 401, json: "{}")
        await runCurrent()
        open()
        await runCurrent()
        base.respond(json: "[]")
        base.respond(json: "[]")

        #expect(try await first.value == 200)
        #expect(try await second.value == 200)
        #expect(refreshes == 1)
        #expect(sentTokens == ["Bearer old", "Bearer old", "Bearer new", "Bearer new"])
    }

    /// 갱신이 끝난 뒤에 도착한 옛 토큰의 401은 이미 바뀐 토큰으로 다시 보낸다.
    @Test func lateUnauthorizedAfterRefreshRetriesWithCurrentToken() async throws {
        let transport = makeTransport()
        let first = send(transport)
        let second = send(transport)
        await runCurrent()

        base.respond(status: 401, json: "{}")
        await runCurrent()
        base.respond(status: 401, json: "{}")
        await runCurrent()
        base.respond(json: "[]")
        base.respond(json: "[]")

        #expect(try await first.value == 200)
        #expect(try await second.value == 200)
        #expect(refreshes == 1)
        #expect(sentTokens == ["Bearer old", "Bearer old", "Bearer new", "Bearer new"])
    }
}
