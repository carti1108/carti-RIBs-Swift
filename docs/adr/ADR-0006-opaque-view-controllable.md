### ADR-0006 ViewControllable을 불투명한 타입으로 둔다
- 상태: 채택
- 날짜: 2026-11-13
- 배경: RIBs-iOS `ViewControllable`은 `uiviewController`를 노출해 UIKit에 묶인다. 코어는 UIKit 없는 플랫폼에서도 빌드돼야 한다(ADR-0004).
- 결정: `ViewControllable`은 멤버 없는 `@MainActor AnyObject` 프로토콜이다. 루트 뷰를 붙이는 쪽은 `ViewHost<View>` 프로토콜(`show`/`hide`)로 추상화하고, `LaunchRouter.launch(from:)`는 `UIWindow` 대신 `ViewHost`를 받는다. 실제 화면 조작은 플랫폼 어댑터가 맡는다.
- 고려했던 대안:
  (1) `#if canImport(UIKit)`로 `uiviewController` 노출: 플랫폼별로 API가 달라져 기각했다.
  (2) 뷰 타입을 제네릭 인자로만 두고 프로토콜 없음: `viewControllable` 소거 타입을 둘 수 없어 기각했다.
- 결과: 코어는 뷰 내용을 모른다. UIKit·AppKit·SwiftUI 어댑터는 별도 타깃(M3, M4)에서 `ViewControllable`과 `ViewHost`를 구현한다.
- 관련: ADR-0004, carti-RIBs-KMP ADR-0004
