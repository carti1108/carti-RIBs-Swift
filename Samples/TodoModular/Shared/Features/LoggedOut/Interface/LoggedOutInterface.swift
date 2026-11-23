import RIBs
import TodoCore

/// 뷰 → 공유 코드: 사용자 입력.
@MainActor
public protocol LoggedOutPresentableListener: AnyObject {
    func didTapLogin(rawName: String)
}

/// 공유 코드 → 뷰. 플랫폼이 구현한다.
@MainActor
public protocol LoggedOutPresentable: Presentable {
    /// 활성 구간에만 설정된다. 비활성이면 nil이라 입력이 무시된다. 플랫폼은 `weak`로 둔다.
    var listener: (any LoggedOutPresentableListener)? { get set }
    func showError(_ message: String?)
    func showLoading(_ isLoading: Bool)
}

/// Router → 뷰. 붙일 자식 화면이 없어 비어 있다.
@MainActor
public protocol LoggedOutViewControllable: ViewControllable {}

@MainActor
public protocol LoggedOutViewContract: LoggedOutPresentable, LoggedOutViewControllable {}

/// 플랫폼이 이 피처의 뷰를 만들어 준다.
@MainActor
public protocol LoggedOutViewFactory: AnyObject {
    func makeLoggedOutView() -> any LoggedOutViewContract
}

@MainActor
public protocol LoggedOutDependency: Dependency {
    var authService: any AuthService { get }
}

/// 자식 → 부모: 로그인 성공. 라우팅은 부모가 정한다.
@MainActor
public protocol LoggedOutListener: AnyObject {
    func didLogin(userName: String)
}

@MainActor
public protocol LoggedOutBuildable: Buildable {
    func build(listener: any LoggedOutListener) -> any ViewableRouting
}
