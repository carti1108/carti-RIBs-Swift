import RIBs
import TodoCore

/// 메인 액터에 쌓인 Task가 다음 대기 지점까지 돌도록 양보한다(코루틴 테스트의 `runCurrent`).
@MainActor
public func runCurrent() async {
    for _ in 0..<50 { await Task.yield() }
}

/// 시간을 테스트가 넘기는 시계. 실제로 자지 않는다.
@MainActor
public final class ManualClock: TodoClock {
    private struct Sleeper {
        let deadline: Duration
        let continuation: CheckedContinuation<Void, Never>
    }

    public private(set) var now: Duration = .zero
    private var sleepers: [UInt64: Sleeper] = [:]
    private var nextID: UInt64 = 0

    public init() {}

    public func sleep(for duration: Duration) async throws(CancellationError) {
        let id = nextID
        nextID += 1
        let deadline = now + duration
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if Task.isCancelled {
                    continuation.resume()
                } else {
                    sleepers[id] = Sleeper(deadline: deadline, continuation: continuation)
                }
            }
        } onCancel: {
            Task { @MainActor in self.wake(id) }
        }
        if Task.isCancelled { throw CancellationError() }
    }

    /// `duration`만큼 시간을 넘기며 마감이 지난 대기를 순서대로 깨운다.
    public func advance(by duration: Duration) async {
        let target = now + duration
        while let (id, sleeper) = sleepers.filter({ $0.value.deadline <= target })
            .min(by: { $0.value.deadline < $1.value.deadline })
        {
            now = sleeper.deadline
            wake(id)
            await runCurrent()
        }
        now = target
    }

    private func wake(_ id: UInt64) {
        sleepers.removeValue(forKey: id)?.continuation.resume()
    }
}

/// 응답 시점을 테스트가 정하는 인증 서비스.
@MainActor
public final class FakeAuthService: AuthService {
    public private(set) var requests: [String] = []
    public private(set) var wasCancelled = false
    private var pending: CheckedContinuation<AuthResult?, Never>?

    public init() {}

    public func signIn(userName: String) async throws(CancellationError) -> AuthResult {
        requests.append(userName)
        let result = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                pending = continuation
            }
        } onCancel: {
            Task { @MainActor in self.finish(nil) }
        }
        guard let result else {
            wasCancelled = true
            throw CancellationError()
        }
        return result
    }

    public func respond(_ result: AuthResult) { finish(result) }

    private func finish(_ result: AuthResult?) {
        let continuation = pending
        pending = nil
        continuation?.resume(returning: result)
    }
}

/// 응답 시점을 테스트가 정하는 할 일 저장소. `autoResponse`를 주면 기다리지 않고 바로 답한다.
@MainActor
public final class FakeTodoRepository: TodoRepository {
    public private(set) var requests = 0
    public private(set) var cancellations = 0
    private let autoResponse: Result<[Todo], TodoRepositoryError>?
    private var pending: CheckedContinuation<Result<[Todo], TodoRepositoryError>, Never>?

    public init(autoResponse: Result<[Todo], TodoRepositoryError>? = nil) {
        self.autoResponse = autoResponse
    }

    public func loadTodos() async throws(TodoRepositoryError) -> [Todo] {
        requests += 1
        if let autoResponse { return try autoResponse.get() }
        let result = await withTaskCancellationHandler {
            await withCheckedContinuation { pending = $0 }
        } onCancel: {
            Task { @MainActor in
                guard self.pending != nil else { return }
                self.cancellations += 1
                self.respond(.failure(.cancelled))
            }
        }
        return try result.get()
    }

    public func respond(_ result: Result<[Todo], TodoRepositoryError>) {
        let continuation = pending
        pending = nil
        continuation?.resume(returning: result)
    }
}

/// 피처를 단독으로 테스트할 때 부모 역할을 하는 Router. 자식을 붙이면 활성화되고, 떼면 비활성화된다.
@MainActor
public final class TestParentRouter {
    public let router = Router(interactor: Interactor())

    public init() {
        router.load()
        router.interactable.activate()
    }

    public func attach(_ child: any Routing) { router.attachChild(child) }

    public func detach(_ child: any Routing) { router.detachChild(child) }
}

/// 자식 Buildable 가짜가 돌려주는 빈 Router. 뷰만 가진다.
public typealias StubRouter<View> = ViewableRouter<Interactor, View>
