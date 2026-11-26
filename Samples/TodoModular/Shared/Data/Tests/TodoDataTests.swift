import Testing
import TodoCore
import TodoCoreTesting
import TodoData

@MainActor
struct RemoteTodoRepositoryTests {
    private let transport = FakeHTTPTransport()
    private let repository: RemoteTodoRepository

    init() {
        repository = RemoteTodoRepository(client: TodoAPIClient(transport: transport))
    }

    private func load() -> Task<Result<[Todo], TodoRepositoryError>, Never> {
        Task { [repository] in
            do throws(TodoRepositoryError) {
                return .success(try await repository.loadTodos())
            } catch {
                return .failure(error)
            }
        }
    }

    @Test func requestsTodosAndMapsResponseToDomain() async {
        let task = load()
        await runCurrent()
        #expect(transport.requests == [HTTPRequest(method: .get, path: "/todos")])

        transport.respond(json: #"[{"id": 1, "title": "우유 \"사기\"", "done": true}, {"id": 2, "title": "운동", "done": false}]"#)

        #expect(await task.value == .success([
            Todo(id: 1, title: "우유 \"사기\"", isDone: true),
            Todo(id: 2, title: "운동", isDone: false),
        ]))
    }

    @Test func unknownFieldsAreIgnored() async {
        let task = load()
        await runCurrent()

        transport.respond(json: #"[{"id": 9, "title": "새 필드", "done": false, "priority": 3}]"#)

        #expect(await task.value == .success([Todo(id: 9, title: "새 필드", isDone: false)]))
    }

    @Test(arguments: [
        #"{"id": 1}"#,
        #"[{"id": "1", "title": "문자열 id", "done": false}]"#,
        #"[{"id": 1, "title": "done 없음"}]"#,
        "not json",
        "",
    ])
    func malformedBodyIsUnavailable(json: String) async {
        let task = load()
        await runCurrent()

        transport.respond(json: json)

        #expect(await task.value == .failure(.unavailable))
    }

    @Test(arguments: [199, 300, 404, 500])
    func errorStatusIsUnavailable(status: Int) async {
        let task = load()
        await runCurrent()

        transport.respond(status: status, json: "[]")

        #expect(await task.value == .failure(.unavailable))
    }

    /// 401은 피처가 다시 로그인으로 보낼 수 있게 따로 알린다.
    @Test func unauthorizedStatusIsUnauthorized() async {
        let task = load()
        await runCurrent()

        transport.respond(status: 401, json: #"{"title":"토큰 만료"}"#)

        #expect(await task.value == .failure(.unauthorized))
    }

    @Test func transportFailureIsUnavailable() async {
        let task = load()
        await runCurrent()

        transport.respond(.failure(.unreachable))

        #expect(await task.value == .failure(.unavailable))
    }

    @Test func cancellingTheTaskCancelsTheRequest() async {
        let task = load()
        await runCurrent()

        task.cancel()

        #expect(await task.value == .failure(.cancelled))
    }
}

@MainActor
struct TodoAPIClientTests {
    private let transport = FakeHTTPTransport()

    /// 클라이언트는 실패 이유를 구분해 던진다. 저장소가 이를 피처용 오류로 줄인다.
    @Test func reportsWhyItFailed() async {
        let client = TodoAPIClient(transport: transport)
        let badStatus = Task { () -> TodoAPIError? in
            do throws(TodoAPIError) { _ = try await client.fetchTodos(); return nil } catch { return error }
        }
        await runCurrent()
        transport.respond(status: 503, json: "")
        #expect(await badStatus.value == .badStatus(503))

        let malformed = Task { () -> TodoAPIError? in
            do throws(TodoAPIError) { _ = try await client.fetchTodos(); return nil } catch { return error }
        }
        await runCurrent()
        transport.respond(json: "{")
        #expect(await malformed.value == .malformedBody)
    }
}

@MainActor
struct SampleTodoServerTests {
    /// 샘플 앱이 쓰는 가짜 전송이 돌려주는 JSON은 실제 클라이언트로 디코딩된다.
    @Test func servesSampleTodosThroughTheRealClient() async throws {
        let repository = RemoteTodoRepository(client: TodoAPIClient(transport: SampleTodoServer()))

        let todos = try await repository.loadTodos()

        #expect(todos == TodoStore.sampleTodos)
    }

    /// 플랫폼 UI 테스트가 실패 화면과 다시 시도를 확인할 때 쓴다.
    @Test func failsTheConfiguredNumberOfTimesThenSucceeds() async throws {
        let server = SampleTodoServer(failuresBeforeSuccess: 2)
        let request = HTTPRequest(method: .get, path: "/todos")

        #expect(try await server.send(request).status == 503)
        #expect(try await server.send(request).status == 503)
        #expect(try await server.send(request).status == 200)
    }

    @Test func unknownPathIsNotFound() async throws {
        let response = try await SampleTodoServer().send(HTTPRequest(method: .get, path: "/nope"))

        #expect(response.status == 404)
    }
}
