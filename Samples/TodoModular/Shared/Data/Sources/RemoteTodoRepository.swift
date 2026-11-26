import TodoCore

/// API에서 할 일을 가져오는 저장소. 실패 이유는 피처가 다르게 다루는 세 가지(취소, 지금 못 가져옴, 인증 거절)로 줄인다.
@MainActor
public final class RemoteTodoRepository: TodoRepository {
    private let client: TodoAPIClient

    public init(client: TodoAPIClient) {
        self.client = client
    }

    public func loadTodos() async throws(TodoRepositoryError) -> [Todo] {
        do {
            return try await client.fetchTodos()
        } catch {
            switch error {
            case .cancelled: throw .cancelled
            case .unauthorized: throw .unauthorized
            case .unreachable, .conflict, .badStatus, .malformedBody: throw .unavailable
            }
        }
    }
}
