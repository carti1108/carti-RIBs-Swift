import TodoCore

/// 샘플 앱이 서버 대신 쓰는 전송 계층. 네트워크 없이 JSON 본문을 돌려준다.
/// 실제 앱은 이 자리에 플랫폼의 전송 구현을 넣는다. 그 위(`TodoAPIClient`, `RemoteTodoRepository`)는 그대로다.
@MainActor
public final class SampleTodoServer: HTTPTransport {
    static let todosJSON = """
        [
          {"id": 1, "title": "우유 사기", "done": false},
          {"id": 2, "title": "RIB 문서 읽기", "done": false},
          {"id": 3, "title": "운동하기", "done": false}
        ]
        """

    private let delay: Duration
    private var remainingFailures: Int
    private let clock: any TodoClock

    /// `failuresBeforeSuccess`번은 503을 돌려준 뒤 성공한다. UI 테스트가 실패 화면과 다시 시도를 확인할 때 쓴다.
    public init(delay: Duration = .zero, failuresBeforeSuccess: Int = 0, clock: any TodoClock = TaskSleepClock()) {
        precondition(delay >= .zero, "delay must not be negative: \(delay)")
        precondition(failuresBeforeSuccess >= 0, "failuresBeforeSuccess must not be negative: \(failuresBeforeSuccess)")
        self.delay = delay
        remainingFailures = failuresBeforeSuccess
        self.clock = clock
    }

    public func send(_ request: HTTPRequest) async throws(HTTPTransportError) -> HTTPResponse {
        // 지연이 없으면 시계를 거치지 않는다. 실제 시계는 0초를 자도 다음 틱까지 미뤄진다.
        if delay > .zero {
            do {
                try await clock.sleep(for: delay)
            } catch {
                // `TodoClock.sleep`은 `CancellationError`만 던진다.
                throw .cancelled
            }
        }
        guard request == HTTPRequest(method: .get, path: "/todos") else {
            return HTTPResponse(status: 404, body: [])
        }
        guard remainingFailures == 0 else {
            remainingFailures -= 1
            return HTTPResponse(status: 503, body: [])
        }
        return HTTPResponse(status: 200, body: Array(Self.todosJSON.utf8))
    }
}
