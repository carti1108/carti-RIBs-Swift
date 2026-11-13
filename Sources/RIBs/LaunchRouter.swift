/// 앱의 루트 RIB을 시작하는 Router. RIBs-iOS `LaunchRouting`.
@MainActor
public protocol LaunchRouting: ViewableRouting {
    associatedtype LaunchView: ViewControllable
    func launch(from host: some ViewHost<LaunchView>, savedInstanceState: RibState?)
    func shutdown()
}

/// RIBs-iOS `LaunchRouter`. `launch(from: UIWindow)` 대신 `ViewHost`를 받는다.
/// 순서(원본과 같음): 뷰 표시 → 활성화 → `load`.
///
/// 원본에 없는 확장: `shutdown`으로 트리 전체를 비활성화하고 뷰를 숨긴다. 저장 상태를 넘기면 복원한다.
@MainActor
open class LaunchRouter<InteractorType, ViewControllerType: ViewControllable>:
    ViewableRouter<InteractorType, ViewControllerType>, LaunchRouting
{
    public typealias LaunchView = ViewControllerType

    private var activeMount: RibMount?

    public override init(interactor: InteractorType, viewController: ViewControllerType) {
        super.init(interactor: interactor, viewController: viewController)
    }

    public final func launch(from host: some ViewHost<ViewControllerType>, savedInstanceState: RibState? = nil) {
        precondition(activeMount == nil, "\(Self.defaultTag(self)) is already launched")
        activeMount = mount(host: host, savedInstanceState: savedInstanceState)
    }

    /// 트리 전체를 비활성화하고 뷰를 숨긴다. 시작 전이거나 이미 끝났으면 아무 일도 하지 않는다.
    public final func shutdown() {
        activeMount?.unmount()
        activeMount = nil
    }
}
