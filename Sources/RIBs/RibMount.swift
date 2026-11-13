/// RIB이 없는 호스트에 붙인 하위 트리의 핸들. 원본 RIBs에는 없는 확장이다.
@MainActor
public final class RibMount {
    private var onUnmount: (() -> Void)?

    public var isMounted: Bool { onUnmount != nil }

    init(onUnmount: @escaping () -> Void) {
        self.onUnmount = onUnmount
    }

    /// 하위 트리를 비활성화한다. 여러 번 불러도 한 번만 동작한다.
    public func unmount() {
        let action = onUnmount
        onUnmount = nil
        action?()
    }
}

extension Router {
    /// 뷰 없이 이 Router의 하위 트리를 활성화하고 로드한다.
    public final func mount(savedInstanceState: RibState? = nil) -> RibMount {
        activateAsRoot(savedInstanceState: savedInstanceState)
        return RibMount { [self] in deactivateAsRoot() }
    }

    func activateAsRoot(savedInstanceState: RibState?) {
        precondition(!interactable.isActive, "\(Self.defaultTag(self)) is already active")
        prepare(state: savedInstanceState, tag: tag ?? Self.defaultTag(self))
        setSubtreeActive(true)
        load()
    }

    /// RIBs-iOS `Router.deinit`과 같은 순서: 자기 Interactor 비활성화 → 자식 전체 detach.
    /// 이어서 로드 상태를 지워, 다시 `mount`하면 `didLoad`가 다시 불려 고정 자식이 붙는다.
    func deactivateAsRoot() {
        interactable.deactivate()
        children.forEach(detachChild)
        resetLoad()
    }
}

extension ViewableRouter where ViewControllerType: ViewControllable {
    /// 뷰를 `host`에 보여 준 뒤 하위 트리를 활성화하고 로드한다(RIBs-iOS `LaunchRouter.launch` 순서).
    /// `unmount`는 비활성화 후 뷰를 숨긴다.
    public final func mount(
        host: some ViewHost<ViewControllerType>,
        savedInstanceState: RibState? = nil
    ) -> RibMount {
        precondition(!interactable.isActive, "\(Self.defaultTag(self)) is already active")
        host.show(viewController)
        activateAsRoot(savedInstanceState: savedInstanceState)
        return RibMount { [self] in
            deactivateAsRoot()
            host.hide(viewController)
        }
    }
}
