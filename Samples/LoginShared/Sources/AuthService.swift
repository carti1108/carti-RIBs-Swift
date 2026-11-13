/// 로그인 결과. 실패는 사용자에게 보여 줄 메시지를 담는다.
public enum AuthResult: Equatable, Sendable {
    case success(userName: String)
    case failure(message: String)
}

/// 로그인 요청을 처리하는 서비스. 호출한 Task가 취소되면 요청도 취소되고 `CancellationError`를 던진다.
@MainActor
public protocol AuthService: AnyObject {
    func signIn(userName: String) async throws(CancellationError) -> AuthResult
}

/// 네트워크 대신 지연만 주는 샘플 서비스. 이름이 `failingName`이면 실패한다.
@MainActor
public final class DelayedAuthService: AuthService {
    public static let failingName = "fail"
    public static let failureMessage = "로그인에 실패했습니다"

    private let delay: Duration
    private let clock: any LoginClock

    public init(delay: Duration, clock: any LoginClock = TaskSleepClock()) {
        precondition(delay >= .zero, "delay must not be negative: \(delay)")
        self.delay = delay
        self.clock = clock
    }

    public func signIn(userName: String) async throws(CancellationError) -> AuthResult {
        try await clock.sleep(for: delay)
        return userName == Self.failingName
            ? .failure(message: Self.failureMessage)
            : .success(userName: userName)
    }
}
