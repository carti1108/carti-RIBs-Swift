/// Interactor가 상태를 보내는 대상의 표식. RIBs-iOS `Presentable`.
@MainActor
public protocol Presentable: AnyObject {}

/// 뷰와 Interactor 사이에 따로 두는 Presenter. RIBs-iOS `Presenter<ViewControllerType>`. 생명주기는 없다.
@MainActor
open class Presenter<ViewControllerType>: Presentable {
    public let viewController: ViewControllerType

    public init(viewController: ViewControllerType) {
        self.viewController = viewController
    }
}
