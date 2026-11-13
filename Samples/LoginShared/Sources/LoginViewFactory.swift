import RIBs

/// 플랫폼이 RIB마다 뷰를 만들어 주는 팩토리. 루트 Dependency로 주입한다(ADR-0008).
/// 각 뷰 계약(`XxxViewContract`)은 해당 RIB 파일에 있다.
///
/// 루트 뷰만 연관 타입이다. `LaunchRouter`와 `ViewHost`는 구체 뷰 타입을 요구하는데,
/// `any RootViewControllable` 같은 프로토콜 존재 타입은 `ViewControllable`을 따르지 않기 때문이다.
@MainActor
public protocol LoginViewFactory: AnyObject {
    associatedtype RootView: RootViewControllable
    func makeRootView() -> RootView
    func makeLoggedOutView() -> any LoggedOutViewContract
    func makeLoggedInView() -> any LoggedInViewContract
    func makeTodoListView() -> any TodoListViewContract
    func makeTodoDetailView() -> any TodoDetailViewContract
}
