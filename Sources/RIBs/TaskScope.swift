/// 활성 구간마다 Task 묶음을 관리하고 구간이 끝나면 모두 취소한다. RxSwift `DisposeBag` 자리.
@MainActor
final class TaskScope {
    private let ownerName: String
    private var tasks: [UInt64: Task<Void, Never>] = [:]
    private var nextID: UInt64 = 0
    private var hasEnded = false
    private(set) var isActive = false

    init(ownerName: String) {
        self.ownerName = ownerName
    }

    func start() {
        precondition(!isActive, "\(ownerName) is already active")
        isActive = true
    }

    /// 구간을 끝내고 남은 Task를 취소한다.
    func end() {
        precondition(isActive, "\(ownerName) is not active")
        isActive = false
        hasEnded = true
        let running = tasks.values
        tasks = [:]
        running.forEach { $0.cancel() }
    }

    func run(_ operation: @escaping @MainActor () async -> Void) throws(LifecycleError) -> Task<Void, Never> {
        guard isActive else {
            throw hasEnded ? .ended(owner: ownerName) : .notStarted(owner: ownerName)
        }
        let id = nextID
        nextID += 1
        let task = Task { @MainActor [weak self] in
            await operation()
            self?.tasks[id] = nil
        }
        tasks[id] = task
        return task
    }
}
