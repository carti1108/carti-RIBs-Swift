import JavaScriptKit
import TodoData

/// 쓰기 요청 스파이크(#31). 다른 출처의 API에 인증 헤더를 붙여 `POST /todos`를 보내고, 공유 코드가 분류한 결과를 `#result`에 쓴다.
/// 화면과 피처는 거치지 않는다. E2E가 결과 문자열로 성공·401·409·5xx·CORS 거부를 확인한다.
@MainActor
enum WriteRequestSpike {
    private static var running: Task<Void, Never>?

    /// `token`이 빈 문자열이면 `Authorization` 헤더 없이 보낸다.
    static func run(baseURL: String, token: String, title: String) {
        precondition(running == nil, "the write request spike runs once per page")
        let transport = BearerTokenTransport(
            base: FetchHTTPTransport(baseURL: baseURL),
            token: { token.isEmpty ? nil : token }
        )
        let client = TodoAPIClient(transport: transport)
        running = Task {
            let outcome: String
            do throws(TodoAPIError) {
                let todo = try await client.createTodo(title: title)
                outcome = "created \(todo.id) \(todo.title)"
            } catch {
                outcome = describe(error)
            }
            show(outcome)
        }
    }

    /// 공유 클라이언트를 거치지 않고 요청 하나를 그대로 보낸다. PATCH·DELETE가 `fetch`로 나가는지 확인할 때 쓴다.
    /// 결과는 `status <코드>` 또는 전송 오류 이름이다. `body`가 빈 문자열이면 본문 없이 보낸다.
    static func send(baseURL: String, token: String, method: String, path: String, body: String) {
        precondition(running == nil, "the write request spike runs once per page")
        guard let method = HTTPRequest.Method(rawValue: method) else {
            preconditionFailure("unsupported HTTP method: \(method)")
        }
        let transport = BearerTokenTransport(
            base: FetchHTTPTransport(baseURL: baseURL),
            token: { token.isEmpty ? nil : token }
        )
        let request = HTTPRequest(
            method: method,
            path: path,
            headers: body.isEmpty ? [:] : ["Content-Type": "application/json"],
            body: body.isEmpty ? nil : body
        )
        running = Task {
            let outcome: String
            do throws(HTTPTransportError) {
                outcome = "status \(try await transport.send(request).status)"
            } catch {
                outcome = "\(error)"
            }
            show(outcome)
        }
    }

    private static func show(_ outcome: String) {
        _ = JSObject.global.document.getElementById("result").object!.textContent = .string(outcome)
    }

    private static func describe(_ error: TodoAPIError) -> String {
        switch error {
        case .cancelled: "cancelled"
        case .unreachable: "unreachable"
        case let .unauthorized(problem): "unauthorized: \(title(of: problem))"
        case let .conflict(problem): "conflict: \(title(of: problem))"
        case let .badStatus(status, problem): "status \(status): \(title(of: problem))"
        case .malformedBody: "malformed body"
        }
    }

    private static func title(of problem: ProblemDetails?) -> String {
        problem?.title ?? "-"
    }
}
