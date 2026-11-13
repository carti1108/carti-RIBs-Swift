/// 플랫폼 뷰를 가리키는 불투명한 타입. RIBs-iOS `ViewControllable`.
/// 코어는 내용을 모르고, 실제 화면 붙이기·떼기는 플랫폼 어댑터가 맡는다.
@MainActor
public protocol ViewControllable: AnyObject {}

/// RIB 트리 바깥의 화면 컨테이너(UIWindow, NSWindow, DOM 컨테이너 등). 플랫폼 어댑터가 구현한다.
@MainActor
public protocol ViewHost<View>: AnyObject {
    associatedtype View: ViewControllable
    func show(_ view: View)
    func hide(_ view: View)
}
