### ADR-0007 SwiftUI·UIKit 어댑터를 별도 타깃으로 둔다
- 상태: 채택
- 날짜: 2026-11-13
- 배경: 코어 `ViewControllable`은 멤버가 없다(ADR-0006). 앱은 RIB 뷰를 SwiftUI나 UIKit으로 그려야 하고, 부모 화면은 공유 코드가 넘긴 `any ViewControllable`에서 실제 화면을 꺼내야 한다. carti-RIBs-KMP는 Kotlin 객체를 Swift로 다운캐스트하는 `RIBsKMPSwiftUI`를 따로 두었다.
- 결정:
  - `RIBsSwiftUI`: `SwiftUIRenderable: ViewControllable`(`makeView() -> AnyView`), 자식 화면 하나를 담는 `@Observable RIBScreenSlot`과 이를 그리는 `RIBSlotView`, 루트용 `SwiftUIViewHost<View>`. 슬롯은 `any ViewControllable`도 받고, SwiftUI로 그릴 수 없는 뷰면 `precondition`으로 실패한다.
  - `RIBsUIKit`(`#if canImport(UIKit)`): RIBs-iOS와 같은 `UIKitViewControllable.uiviewController`(`UIViewController`이면 기본 구현), `ViewControllable.uiviewController` 변환, `UIWindow`에 붙이는 `WindowViewHost<View>`, 자식 화면 하나를 child view controller로 담는 `RIBContainerViewController`.
  - 두 타깃 모두 `RIBs`에만 의존한다. 코어는 이 타깃을 모른다.
- 고려했던 대안:
  (1) 코어에 `#if canImport(SwiftUI)` 확장: 코어가 플랫폼 프레임워크에 묶이고 Wasm·Android 빌드 조건이 복잡해져 기각했다.
  (2) KMP처럼 `show(anyView: AnyObject) -> Bool`로 실패를 무시: 순수 Swift에서는 타입이 같은 모듈 체계 안에 있으므로 조용히 무시할 이유가 없어 계약 위반으로 실패시키기로 했다.
  (3) `ObservableObject` 사용: Combine을 끌어오므로 기각했다(ADR-0002). 대신 Apple 플랫폼 최소 버전을 iOS 17·macOS 14로 올렸다.
- 결과: 코어의 활성 상태 구독 핸들은 `ActiveObservation`이라 Observation 모듈을 가리지 않는다. `import RIBs`한 파일에서도 `@Observable`을 쓸 수 있다(처음에는 `Observation`이라는 이름이 모듈을 가려 `@Observable` 타입을 따로 둔 파일에 격리했으나, 이름을 바꿔 그 제약을 없앴다).
- 관련: ADR-0002, ADR-0004, ADR-0006, carti-RIBs-KMP ADR-0006
