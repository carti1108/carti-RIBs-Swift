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
