#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import TodoCore

public enum TodoAPIError: Error, Equatable, Sendable {
    case cancelled
    case unreachable
    case badStatus(Int)
    case malformedBody
}

/// 서버가 주는 모양. 필드 이름이 도메인(`Todo.isDone`)과 달라 따로 둔다. 모르는 필드는 무시한다.
private struct TodoDTO: Decodable {
    let id: Int64
    let title: String
    let done: Bool

    var todo: Todo { Todo(id: id, title: title, isDone: done) }
}

/// 할 일 API. 요청을 만들고, 상태 코드를 확인하고, 본문을 `Todo`로 바꾼다.
@MainActor
public final class TodoAPIClient {
    private static let successStatuses = 200..<300

    private let transport: any HTTPTransport

    public init(transport: any HTTPTransport) {
        self.transport = transport
    }

    public func fetchTodos() async throws(TodoAPIError) -> [Todo] {
        let response: HTTPResponse
        do {
            response = try await transport.send(HTTPRequest(method: .get, path: "/todos"))
        } catch {
            switch error {
            case .cancelled: throw .cancelled
            case .unreachable: throw .unreachable
            }
        }
        guard Self.successStatuses.contains(response.status) else { throw .badStatus(response.status) }
        do {
            return try JSONDecoder().decode([TodoDTO].self, from: Data(response.body)).map(\.todo)
        } catch {
            throw .malformedBody
        }
    }
}
