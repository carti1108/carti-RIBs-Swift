import FeatureTodoDetailInterface
import FeatureTodoListInterface
import RIBs
import TodoCore

/// 머리말에 그릴 값. 자식 화면은 상태가 아니라 `LoggedInViewControllable`로 붙인다(ADR-0025).
public struct LoggedInViewState: Equatable, Sendable {
    public var userName: String
    public var sessionSeconds: Int64

    public init(userName: String, sessionSeconds: Int64 = 0) {
        self.userName = userName
        self.sessionSeconds = sessionSeconds
    }
}

public enum LoggedInViewAction: Equatable, Sendable {
    case logoutTapped
    /// 사용자가 스와이프·브라우저 뒤로 가기 같은 플랫폼 제스처로 상세를 닫았다.
    /// 뷰는 화면을 이미 뺀 뒤에 이 액션을 보낸다(ADR-0030).
    case detailDismissedByUser
}

@MainActor
public protocol LoggedInPresentableListener: AnyObject {
    func handle(_ action: LoggedInViewAction)
}

/// Interactor → 뷰: 머리말(사용자 이름, 세션 시간)을 그린다.
@MainActor
public protocol LoggedInPresentable: Presentable {
    var listener: (any LoggedInPresentableListener)? { get set }
    func render(_ state: LoggedInViewState)
}

/// Router → 뷰: 자식 화면을 붙이고 뗀다.
/// 이름은 무엇을 보여 줄지만 말한다. 상세를 스택에 쌓을지, 시트로 띄울지, 목록 옆에 둘지는 플랫폼 뷰가 정한다(ADR-0030).
@MainActor
public protocol LoggedInViewControllable: ViewControllable {
    func showList(_ screen: any ViewControllable)
    func showDetail(_ screen: any ViewControllable)
    /// 이미 없는 화면이면 아무 일도 하지 않는다. 사용자가 제스처로 닫은 뒤에도 Router가 부른다.
    func hideDetail(_ screen: any ViewControllable)
}

@MainActor
public protocol LoggedInViewContract: LoggedInPresentable, LoggedInViewControllable {}

@MainActor
public protocol LoggedInViewFactory: AnyObject {
    func makeLoggedInView() -> any LoggedInViewContract
}

/// 자식 Builder는 조립 모듈이 만들어 준다. 이 피처는 자식의 Interface만 안다(ADR-0024).
@MainActor
public protocol LoggedInDependency: Dependency {
    var clock: any TodoClock { get }
    var todoRepository: any TodoRepository { get }
    func makeTodoListBuilder(dependency: any TodoListDependency) -> any TodoListBuildable
    func makeTodoDetailBuilder(dependency: any TodoDetailDependency) -> any TodoDetailBuildable
}

@MainActor
public protocol LoggedInListener: AnyObject {
    func didRequestLogout()
}

/// 부모가 뒤로 가기를 맡길 때 쓴다.
@MainActor
public protocol LoggedInRouting: ViewableRouting {
    func handleBackPress() -> Bool
}

@MainActor
public protocol LoggedInBuildable: Buildable {
    func build(listener: any LoggedInListener, userName: String) -> any LoggedInRouting
}
