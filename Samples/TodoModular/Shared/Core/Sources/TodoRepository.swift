/// 피처가 보는 실패. 이유(상태 코드, 디코딩 실패)는 데이터 계층 안에 둔다.
public enum TodoRepositoryError: Error, Equatable, Sendable {
    /// 부른 Task가 취소됐다.
    case cancelled
    /// 지금은 가져올 수 없다. 다시 시도할 수 있다.
    case unavailable
    /// 서버가 인증을 거절했다. 다시 시도해도 같다. 다시 로그인해야 한다.
    case unauthorized
}

/// 할 일을 가져오는 곳. 피처는 이 프로토콜만 안다. 구현은 데이터 계층(`TodoData`)에 있고 `Component`로 주입한다(ADR-0032).
@MainActor
public protocol TodoRepository: AnyObject {
    /// 호출한 Task가 취소되면 요청도 취소되고 `.cancelled`를 던진다.
    func loadTodos() async throws(TodoRepositoryError) -> [Todo]
}
