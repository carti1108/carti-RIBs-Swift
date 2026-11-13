/// Interactor의 활성 상태를 읽는 범위. RIBs-iOS `InteractorScope`.
@MainActor
public protocol InteractorScope: AnyObject, Sendable {
    var isActive: Bool { get }
    /// 현재 값을 먼저 보내고 바뀔 때만 다시 보낸다.
    var isActiveStream: AsyncStream<Bool> { get }
    /// 현재 값을 즉시 전달하고 바뀔 때마다 동기로 전달한다. Worker가 쓴다.
    func observeActive(_ handler: @escaping @MainActor (Bool) -> Void) -> ActiveObservation
}

/// Router가 활성화·비활성화할 수 있는 Interactor. RIBs-iOS `Interactable`.
@MainActor
public protocol Interactable: InteractorScope {
    func activate()
    func deactivate()
}

/// 비즈니스 로직을 담는 RIB 구성 요소. RIBs-iOS `Interactor`.
///
/// - `didBecomeActive`에서 시작하는 비동기 작업은 `task(_:)`로 띄운다. `willResignActive`가 끝난 뒤 취소된다
///   (원본의 `disposeOnDeactivate`).
/// - 이미 활성인데 `activate`하거나 비활성인데 `deactivate`하면 아무 일도 하지 않는다.
/// - 원본에 없는 확장: 상태 복원(`savedInstanceState`, `onSaveInstanceState`)과 `handleBackPress`.
@MainActor
open class Interactor: Interactable {
    private let activeState = ActiveState()
    private lazy var taskScope = TaskScope(ownerName: String(describing: type(of: self)))

    /// Router가 넘긴 복원 상태. 없으면 nil. `didBecomeActive`에서 읽는다.
    public private(set) var savedInstanceState: RibState?

    public init() {}

    public final var isActive: Bool { activeState.value }

    public final var isActiveStream: AsyncStream<Bool> { activeState.stream() }

    public final func observeActive(_ handler: @escaping @MainActor (Bool) -> Void) -> ActiveObservation {
        activeState.observe(handler)
    }

    public final func activate() {
        guard !isActive else { return }
        taskScope.start()
        activeState.set(true)
        didBecomeActive()
    }

    /// 활성화된 직후 호출된다.
    open func didBecomeActive() {}

    public final func deactivate() {
        guard isActive else { return }
        willResignActive()
        taskScope.end()
        activeState.set(false)
    }

    /// 비활성화 직전에 호출된다. 이 시점까지 `task(_:)`로 띄운 작업은 살아 있다.
    open func willResignActive() {}

    /// 활성 구간에 묶인 Task를 띄운다. 비활성화되면 취소된다.
    /// 활성 전이면 `.notStarted`, 비활성 후면 `.ended`를 던진다.
    @discardableResult
    public final func task(
        _ operation: @escaping @MainActor () async -> Void
    ) throws(LifecycleError) -> Task<Void, Never> {
        try taskScope.run(operation)
    }

    /// 저장할 상태를 채운다. Router가 상태를 저장할 때 호출한다.
    open func onSaveInstanceState(_ outState: inout [String: RibValue]) {}

    /// 뒤로 가기를 처리했으면 true. 원본 iOS에는 없는 확장이다.
    open func handleBackPress() -> Bool { false }

    func restore(_ state: RibState?) {
        savedInstanceState = state
    }

    func saveInstanceState() -> RibState {
        var outState: [String: RibValue] = [:]
        onSaveInstanceState(&outState)
        return RibState(outState)
    }
}

/// 뷰 쪽 연결점을 가진 Interactor. RIBs-iOS `PresentableInteractor`.
@MainActor
open class PresentableInteractor<PresenterType>: Interactor {
    /// 이 Interactor가 상태를 보내는 대상. 보통 뷰가 `XxxPresentable`을 구현한다.
    public let presenter: PresenterType

    public init(presenter: PresenterType) {
        self.presenter = presenter
        super.init()
    }
}

extension AsyncStream where Element: Sendable {
    /// 내부 Task가 값을 꺼내는 시점에 `scope`가 활성이면 내보낸다. RIBs-iOS `confineTo(_:)`.
    /// `AsyncStream`은 값이 yield된 시점을 알려 주지 않으므로, 비활성 중 버퍼에 쌓인 값도 꺼내기 전에
    /// 활성화되면 전달된다. `scope`는 약하게 잡으며, 사라진 뒤 다음 값이 오면 스트림이 끝난다. 원본(combineLatest)과 달리 마지막 값을 재활성 때 다시 내보내지 않는다.
    @MainActor
    public func confineTo(_ scope: some InteractorScope) -> AsyncStream<Element> {
        let source = self
        return AsyncStream { continuation in
            let task = Task { @MainActor [weak scope] in
                for await value in source {
                    guard let scope else { break }
                    if scope.isActive { continuation.yield(value) }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
