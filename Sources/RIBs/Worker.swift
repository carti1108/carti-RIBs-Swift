/// RIBs-iOS `Working`.
@MainActor
public protocol Working: AnyObject {
    var isStarted: Bool { get }
    var isStartedStream: AsyncStream<Bool> { get }
    func start(_ interactorScope: some InteractorScope)
    func stop()
}

/// Interactor 활성 구간에 맞춰 돌아가는 작업 단위. RIBs-iOS `Worker`.
///
/// `start` 뒤에는 Interactor가 활성일 때만 `didStart`가, 비활성이 되거나 `stop`하면 `didStop`이 불린다.
/// `didStart`에서 시작하는 비동기 작업은 `task(_:)`로 띄운다(원본의 `disposeOnStop`).
///
/// 원본과 다른 점: `deinit`에 기대지 않고 `stop`이 Interactor 구독도 끊는다.
@MainActor
open class Worker: Working {
    private let startedState = ActiveState()
    private lazy var taskScope = TaskScope(ownerName: String(describing: type(of: self)))
    private var binding: ActiveObservation?

    public init() {}

    public final var isStarted: Bool { startedState.value }

    public final var isStartedStream: AsyncStream<Bool> { startedState.stream() }

    public final func start(_ interactorScope: some InteractorScope) {
        guard !isStarted else { return }
        stop()
        startedState.set(true)
        binding = interactorScope.observeActive { [weak self, weak interactorScope] isActive in
            guard let self else { return }
            if isActive {
                if self.isStarted, let interactorScope { self.executeStart(interactorScope) }
            } else {
                self.executeStop()
            }
        }
    }

    /// Interactor가 활성인 동안 작업을 시작할 때 호출된다.
    open func didStart(_ interactorScope: any InteractorScope) {}

    public final func stop() {
        binding?.cancel()
        binding = nil
        guard isStarted else { return }
        startedState.set(false)
        executeStop()
    }

    /// 작업이 멈춘 뒤 호출된다. 이 시점에 `task(_:)`로 띄운 작업은 이미 취소되었다.
    open func didStop() {}

    /// 작업 구간에 묶인 Task를 띄운다. 작업이 멈추면 취소된다.
    @discardableResult
    public final func task(
        _ operation: @escaping @MainActor () async -> Void
    ) throws(LifecycleError) -> Task<Void, Never> {
        try taskScope.run(operation)
    }

    private func executeStart(_ interactorScope: any InteractorScope) {
        guard !taskScope.isActive else { return }
        taskScope.start()
        didStart(interactorScope)
    }

    private func executeStop() {
        guard taskScope.isActive else { return }
        taskScope.end()
        didStop()
    }
}
