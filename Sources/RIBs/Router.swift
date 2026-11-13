/// Router 생명주기 이벤트. RIBs-iOS `RouterLifecycle`.
public enum RouterLifecycle: Sendable, Equatable {
    case didLoad
}

/// RIBs-iOS `RouterScope`.
@MainActor
public protocol RouterScope: AnyObject {
    /// 한 번만 쓰는 스트림. `.didLoad`를 보낸 뒤 끝난다. 이미 로드됐으면 바로 `.didLoad`를 보내고 끝난다.
    var lifecycle: AsyncStream<RouterLifecycle> { get }
}

/// RIB 트리의 노드. RIBs-iOS `Routing`. 가짜 자식 Router를 쓸 수 있도록 Router가 부르는 멤버를 모두 둔다.
@MainActor
public protocol Routing: RouterScope {
    var interactable: any Interactable { get }
    var children: [any Routing] { get }
    func load()
    func attachChild(_ child: any Routing)
    func detachChild(_ child: any Routing)
}

/// RIB 트리의 노드. RIBs-iOS `Router<InteractorType>`.
///
/// 순서(원본과 같음):
/// - `attachChild`: 자식 Interactor 활성화 → 자식 하위 트리 활성화 → 자식 `load`(처음 한 번 `didLoad`)
/// - `detachChild`: 자식 하위 트리 비활성화 → 목록에서 제거
///
/// 원본과 다른 점: 하위 트리 활성 전파를 Rx 구독 대신 attach/detach/mount에서 직접 처리한다.
/// 같은 자식을 두 번 붙이면 `precondition`으로 실패한다. 상태 복원과 `handleBackPress`는 확장이다.
@MainActor
open class Router<InteractorType>: Routing {
    public static var childRoutersKey: String { "Router.childRouters" }
    public static var interactorKey: String { "Router.interactor" }

    public let interactor: InteractorType
    public final let interactable: any Interactable

    private var childList: [any Routing] = []
    private var lifecycleContinuations: [UInt64: AsyncStream<RouterLifecycle>.Continuation] = [:]
    private var nextContinuationID: UInt64 = 0
    private var savedState: RibState?

    /// 처음 `load`됐는지.
    public private(set) var isLoaded = false

    /// attach될 때 정해지는 식별자. 자식 저장 상태의 키로 쓴다.
    public private(set) var tag: String?

    /// `interactor`는 `Interactable`이어야 한다. 원본과 같이 런타임에 확인한다.
    public init(interactor: InteractorType) {
        guard let interactable = interactor as? any Interactable else {
            preconditionFailure("\(InteractorType.self) should conform to \((any Interactable).self)")
        }
        self.interactor = interactor
        self.interactable = interactable
    }

    public final var children: [any Routing] { childList }

    public final var lifecycle: AsyncStream<RouterLifecycle> {
        AsyncStream { continuation in
            if isLoaded {
                continuation.yield(.didLoad)
                continuation.finish()
                return
            }
            let id = nextContinuationID
            nextContinuationID += 1
            lifecycleContinuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in self?.lifecycleContinuations[id] = nil }
            }
        }
    }

    public final func load() {
        guard !isLoaded else { return }
        isLoaded = true
        for continuation in takeLifecycleContinuations() {
            continuation.yield(.didLoad)
            continuation.finish()
        }
        didLoad()
    }

    /// 로드 상태를 지워 다음 `load`에서 `didLoad`가 다시 불리게 한다. 기다리던 `lifecycle` 구독은 끝낸다.
    /// `mount`로 붙인 루트를 `unmount`할 때 쓴다.
    func resetLoad() {
        isLoaded = false
        takeLifecycleContinuations().forEach { $0.finish() }
    }

    private func takeLifecycleContinuations() -> [AsyncStream<RouterLifecycle>.Continuation] {
        let continuations = lifecycleContinuations.sorted { $0.key < $1.key }.map(\.value)
        lifecycleContinuations = [:]
        return continuations
    }

    /// `load`될 때 호출된다. 보통 한 번이지만, `unmount` 뒤 다시 `mount`하면 다시 불린다. 고정 자식은 여기서 붙인다.
    open func didLoad() {}

    public final func attachChild(_ child: any Routing) {
        attachChild(child, tag: nextDefaultTag(for: child))
    }

    /// 기본 태그 규칙: 자식 타입 이름이 현재 형제 태그와 겹치지 않으면 그대로 쓰고(KMP와 같음),
    /// 겹치면 `타입이름#1`, `타입이름#2`처럼 비어 있는 가장 작은 번호를 붙인다.
    /// 같은 순서로 붙이면 같은 태그가 나오므로 저장 상태 복원이 맞물린다.
    private func nextDefaultTag(for child: any Routing) -> String {
        let base = Self.defaultTag(child)
        let usedTags = Set(childList.compactMap { ($0 as? any StatefulRouting)?.tag })
        guard usedTags.contains(base) else { return base }
        var index = 1
        while usedTags.contains("\(base)#\(index)") { index += 1 }
        return "\(base)#\(index)"
    }

    /// `tag`를 키로 저장 상태를 복원하며 붙인다. 원본에 없는 확장이다.
    public final func attachChild(_ child: any Routing, tag: String) {
        precondition(
            !childList.contains { $0 === child },
            "Attempt to attach child: \(Self.defaultTag(child)), which is already attached to \(Self.defaultTag(self))."
        )
        childList.append(child)
        (child as? any StatefulRouting)?.prepare(state: childState(for: tag), tag: tag)
        child.setSubtreeActive(true)
        child.load()
    }

    /// 붙어 있지 않은 자식을 떼면 `precondition`으로 실패한다(attach와 대칭).
    public final func detachChild(_ child: any Routing) {
        precondition(
            childList.contains { $0 === child },
            "Attempt to detach child: \(Self.defaultTag(child)), which is not attached to \(Self.defaultTag(self))."
        )
        child.setSubtreeActive(false)
        childList.removeAll { $0 === child }
    }

    /// 뒤로 가기를 처리했으면 true. 기본은 Interactor에 묻는다. 원본 iOS에는 없다.
    open func handleBackPress() -> Bool {
        (interactor as? Interactor)?.handleBackPress() ?? false
    }

    /// 이 Router와 하위 트리의 상태를 저장한다. 원본에 없는 확장이다.
    public final func saveInstanceState() -> RibState {
        var childStates: [String: RibValue] = [:]
        for case let child as any StatefulRouting in childList {
            guard let childTag = child.tag else {
                preconditionFailure("\(Self.defaultTag(child)) has no tag")
            }
            childStates[childTag] = .state(child.saveInstanceState())
        }
        let interactorState = (interactor as? Interactor)?.saveInstanceState() ?? RibState()
        return RibState([
            Self.interactorKey: .state(interactorState),
            Self.childRoutersKey: .state(RibState(childStates)),
        ])
    }

    func prepare(state: RibState?, tag: String) {
        savedState = state
        self.tag = tag
        (interactor as? Interactor)?.restore(state?[Self.interactorKey]?.stateValue)
    }

    private func childState(for tag: String) -> RibState? {
        savedState?[Self.childRoutersKey]?.stateValue?[tag]?.stateValue
    }

    static func defaultTag(_ routing: any Routing) -> String {
        String(describing: type(of: routing))
    }
}

/// 상태 저장·복원을 지원하는 Router. 제네릭 `Router`를 타입 소거해 다루기 위한 내부 프로토콜.
@MainActor
protocol StatefulRouting: Routing {
    var tag: String? { get }
    func prepare(state: RibState?, tag: String)
    func saveInstanceState() -> RibState
}

extension Router: StatefulRouting {}

extension Routing {
    /// 이 노드부터 전위 순회로 Interactor를 켜거나 끈다. 원본 `setSubtreeActive`와 같은 순서.
    func setSubtreeActive(_ active: Bool) {
        if active, !interactable.isActive { interactable.activate() }
        if !active, interactable.isActive { interactable.deactivate() }
        // 콜백에서 형제가 떼어지거나 붙을 수 있으므로, 순회 직전에 아직 자식인지 다시 확인한다.
        for child in children where children.contains(where: { $0 === child }) {
            child.setSubtreeActive(active)
        }
    }
}
