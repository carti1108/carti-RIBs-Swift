import RIBs
@testable import LoginShared

/// 메인 액터에 쌓인 Task가 다음 대기 지점까지 돌도록 양보한다(코루틴 테스트의 `runCurrent`).
@MainActor
func runCurrent() async {
    for _ in 0..<50 { await Task.yield() }
}

/// 시간을 테스트가 넘기는 시계. 실제로 자지 않는다.
@MainActor
final class ManualClock: LoginClock {
    private struct Sleeper {
        let deadline: Duration
        let continuation: CheckedContinuation<Void, Never>
    }

    private(set) var now: Duration = .zero
    private var sleepers: [UInt64: Sleeper] = [:]
    private var cancelled: Set<UInt64> = []
    private var nextID: UInt64 = 0

    func sleep(for duration: Duration) async throws(CancellationError) {
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
    func advance(by duration: Duration) async {
        let target = now + duration
        while let (id, sleeper) = sleepers.filter({ $0.value.deadline <= target }).min(by: { $0.value.deadline < $1.value.deadline }) {
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
final class FakeAuthService: AuthService {
    private(set) var requests: [String] = []
    private(set) var wasCancelled = false
    private var pending: CheckedContinuation<AuthResult?, Never>?

    func signIn(userName: String) async throws(CancellationError) -> AuthResult {
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

    func respond(_ result: AuthResult) { finish(result) }

    private func finish(_ result: AuthResult?) {
        let continuation = pending
        pending = nil
        continuation?.resume(returning: result)
    }
}

@MainActor
final class FakeRootView: RootViewControllable {
    var screen: (any ViewControllable)?
    func showScreen(_ screen: any ViewControllable) { self.screen = screen }
    func hideScreen(_ screen: any ViewControllable) { if self.screen === screen { self.screen = nil } }
}

@MainActor
final class FakeLoggedOutView: LoggedOutViewContract {
    weak var listener: (any LoggedOutPresentableListener)?
    /// 받은 상태를 순서대로 기록한다. 한 번의 갱신이 한 번의 렌더인지 확인할 때 쓴다.
    private(set) var renders: [LoggedOutViewState] = []
    var state: LoggedOutViewState { renders.last ?? LoggedOutViewState() }
    var error: String? { state.errorMessage }
    var isLoading: Bool { state.isLoading }
    func render(_ state: LoggedOutViewState) { renders.append(state) }
}

@MainActor
final class FakeLoggedInView: LoggedInViewContract {
    weak var listener: (any LoggedInPresentableListener)?
    private(set) var renders: [LoggedInViewState] = []
    var userName: String? { renders.last?.userName }
    var sessionSeconds: Int64? { renders.last?.sessionSeconds }
    var screen: (any ViewControllable)?
    func render(_ state: LoggedInViewState) { renders.append(state) }
    func showScreen(_ screen: any ViewControllable) { self.screen = screen }
    func hideScreen(_ screen: any ViewControllable) { if self.screen === screen { self.screen = nil } }
}

@MainActor
final class FakeTodoListView: TodoListViewContract {
    weak var listener: (any TodoListPresentableListener)?
    private(set) var renders: [TodoListViewState] = []
    var todos: [Todo] { renders.last?.todos ?? [] }
    func render(_ state: TodoListViewState) { renders.append(state) }
}

@MainActor
final class FakeTodoDetailView: TodoDetailViewContract {
    weak var listener: (any TodoDetailPresentableListener)?
    private(set) var renders: [TodoDetailViewState] = []
    var title: String? { renders.last?.title }
    var isDone: Bool? { renders.last?.isDone }
    func render(_ state: TodoDetailViewState) { renders.append(state) }
}

@MainActor
final class FakeViewFactory: LoginViewFactory {
    let root = FakeRootView()
    var loggedOut: [FakeLoggedOutView] = []
    var loggedIn: [FakeLoggedInView] = []
    var todoLists: [FakeTodoListView] = []
    var todoDetails: [FakeTodoDetailView] = []

    func makeRootView() -> FakeRootView { root }
    func makeLoggedOutView() -> any LoggedOutViewContract { append(FakeLoggedOutView(), to: &loggedOut) }
    func makeLoggedInView() -> any LoggedInViewContract { append(FakeLoggedInView(), to: &loggedIn) }
    func makeTodoListView() -> any TodoListViewContract { append(FakeTodoListView(), to: &todoLists) }
    func makeTodoDetailView() -> any TodoDetailViewContract { append(FakeTodoDetailView(), to: &todoDetails) }

    private func append<View>(_ view: View, to list: inout [View]) -> View {
        list.append(view)
        return view
    }
}

@MainActor
final class FakeHost: ViewHost {
    var shown: FakeRootView?
    var hidden = false
    func show(_ view: FakeRootView) { shown = view }
    func hide(_ view: FakeRootView) { hidden = true }
}
