#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import TodoCore

public enum TodoAPIError: Error, Equatable, Sendable {
    case cancelled
    /// 응답을 받지 못했다. 브라우저의 CORS 거부도 여기에 든다(`HTTPTransportError.unreachable`).
    case unreachable
    /// 401. 토큰이 없거나 만료됐다.
    case unauthorized(problem: ProblemDetails?)
    /// 409. 서버 상태와 충돌한다.
    case conflict(problem: ProblemDetails?)
    /// 그 밖의 2xx가 아닌 상태.
    case badStatus(Int, problem: ProblemDetails? = nil)
    case malformedBody
}

/// 서버가 주는 모양. 필드 이름이 도메인(`Todo.isDone`)과 달라 따로 둔다. 모르는 필드는 무시한다.
private struct TodoDTO: Decodable {
    let id: Int64
    let title: String
    let done: Bool

    var todo: Todo { Todo(id: id, title: title, isDone: done) }
}

private struct CreateTodoBody: Encodable {
    let title: String
}

/// 할 일 API. 요청을 만들고, 상태 코드를 확인하고, 본문을 `Todo`로 바꾼다.
@MainActor
public final class TodoAPIClient {
    private static let successStatuses = 200..<300
    private static let unauthorizedStatus = 401
    private static let conflictStatus = 409
    private static let jsonHeaders = ["Content-Type": "application/json"]

    private let transport: any HTTPTransport

    public init(transport: any HTTPTransport) {
        self.transport = transport
    }

    public func fetchTodos() async throws(TodoAPIError) -> [Todo] {
        let body = try await send(HTTPRequest(method: .get, path: "/todos"))
        return try decode([TodoDTO].self, from: body).map(\.todo)
    }

    /// `POST /todos`. 서버가 만든 할 일(새 id 포함)을 돌려준다.
    public func createTodo(title: String) async throws(TodoAPIError) -> Todo {
        let request = HTTPRequest(method: .post, path: "/todos", headers: Self.jsonHeaders, body: Self.json(CreateTodoBody(title: title)))
        let body = try await send(request)
        return try decode(TodoDTO.self, from: body).todo
    }

    /// 보내고 상태 코드를 해석한다. 성공이면 본문을 돌려준다.
    private func send(_ request: HTTPRequest) async throws(TodoAPIError) -> [UInt8] {
        let response: HTTPResponse
        do {
            response = try await transport.send(request)
        } catch {
            switch error {
            case .cancelled: throw .cancelled
            case .unreachable: throw .unreachable
            }
        }
        guard Self.successStatuses.contains(response.status) else {
            let problem = ProblemDetails.decode(from: response.body)
            switch response.status {
            case Self.unauthorizedStatus: throw .unauthorized(problem: problem)
            case Self.conflictStatus: throw .conflict(problem: problem)
            default: throw .badStatus(response.status, problem: problem)
            }
        }
        return response.body
    }

    private func decode<T: Decodable>(_ type: T.Type, from body: [UInt8]) throws(TodoAPIError) -> T {
        do {
            return try JSONDecoder().decode(type, from: Data(body))
        } catch {
            throw .malformedBody
        }
    }

    /// 요청 본문은 문자열이다(`HTTPRequest.body`). 문자열 필드만 있는 값이라 인코딩은 실패하지 않는다.
    private static func json(_ value: some Encodable) -> String {
        do {
            return String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
        } catch {
            preconditionFailure("encoding a request body failed: \(error)")
        }
    }
}
