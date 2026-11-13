/// 뷰를 가진 Router. RIBs-iOS `ViewableRouting`.
@MainActor
public protocol ViewableRouting: Routing {
    var viewControllable: any ViewControllable { get }
}

/// RIBs-iOS `ViewableRouter<InteractorType, ViewControllerType>`. 누수 감지는 없다.
@MainActor
open class ViewableRouter<InteractorType, ViewControllerType>: Router<InteractorType>, ViewableRouting {
    public let viewController: ViewControllerType
    public final let viewControllable: any ViewControllable

    /// `viewController`는 `ViewControllable`이어야 한다. 원본과 같이 런타임에 확인한다.
    public init(interactor: InteractorType, viewController: ViewControllerType) {
        guard let viewControllable = viewController as? any ViewControllable else {
            preconditionFailure("\(ViewControllerType.self) should conform to \((any ViewControllable).self)")
        }
        self.viewController = viewController
        self.viewControllable = viewControllable
        super.init(interactor: interactor)
    }
}
