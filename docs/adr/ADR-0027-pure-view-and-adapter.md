### ADR-0027 샘플의 플랫폼 뷰를 순수 뷰와 어댑터로 나눈다
- 상태: 채택
- 날짜: 2026-11-24
- 배경:
  - 샘플의 플랫폼 뷰는 "그리는 코드"와 "공유 코드의 계약을 구현하는 코드"가 한 타입이나 한 파일에 같이 있었다. 그리는 코드가 계약 타입(`XxxViewState`, `XxxViewAction`)이나 생성된 브리지 타입(`XxxScreenHandle`, `XxxViewBridge`)을 직접 참조했다.
    - Android: Composable이 `LoggedOutScreenHandle.init`을 불렀다. Swift 라이브러리가 로드돼 있어야 그려져서 미리보기와 뷰 단독 테스트가 안 됐다. TodoModular의 `:feature:<이름>:ui`는 `:bridge` 전체에 의존해 다른 피처의 핸들 타입까지 볼 수 있었다.
    - iOS: 뷰 struct가 `LoggedOutViewState`·`LoggedOutViewAction`을 받았다. `FeatureXxxUI` 타깃이 `RIBs`, `RIBsSwiftUI`, 자기 Interface에 의존했다.
    - Web: props만 받는 컴포넌트와 브리지 구현 클래스가 한 파일(`view.tsx`)에 있었다(ADR-0026). `WebLogin`은 한 클래스가 DOM을 만들고 핸들을 불렀다.
  - swift-java(1.0 이전)와 BridgeJS(실험 단계)의 생성 타입이 그리는 코드에 퍼져 있으면 도구가 바뀔 때 화면을 모두 고쳐야 한다.
  - 같은 뷰를 다른 공유 코드 구현(예: carti-RIBs-KMP)에 붙이려면 뷰가 어느 구현의 타입도 몰라야 한다.
  - 뷰 계약이 `render(state)`/`handle(action)`으로 정리돼(ADR-0025) 계약과 뷰 사이에서 할 일이 "상태를 인자로 풀고 콜백을 액션으로 묶기"로 줄었다.
- 결정:
  - 샘플의 플랫폼 뷰를 둘로 나눈다.
    - 순수 뷰: 값과 콜백만 받아 그린다. 플랫폼 UI 프레임워크(Compose, SwiftUI, React, DOM)만 import한다. 공유 코드, `RIBs`와 어댑터 타깃, 생성된 브리지 타입을 import하지 않는다. 프로토콜이나 기반 클래스를 새로 두지 않는다.
    - 어댑터: 공유 코드의 뷰 계약(iOS) 또는 브리지 프로토콜(Android, Web)을 구현하고 값을 순수 뷰에 넘긴다. 핸들 생성, 화면 조회, 자식 화면 슬롯 연결, 경계용 타입 변환을 맡는다.
  - 의존 방향은 어댑터 → 순수 뷰, 어댑터 → 공유 코드다. 순수 뷰와 공유 코드는 서로를 모른다. 어댑터는 플랫폼 쪽에 둔다. 공유 패키지와 순수 뷰 모듈에는 두지 않는다.
  - 이름은 플랫폼마다 같게 둔다. 순수 뷰는 `XxxView`, 어댑터는 `XxxAdapter`(브리지 프로토콜 구현) 또는 `XxxScreen`(뷰 계약 구현, 화면 진입점)이다.
  - 순수 뷰의 인자 규칙:
    - 상태는 필드마다 기본 타입 인자로 푼다(`errorMessage: String?`, `isLoading: Bool`).
    - 입력은 콜백으로 받는다(`onLogin: (String) -> Void`).
    - 목록 한 줄처럼 묶음이 필요한 값은 순수 뷰가 타입을 정의하고(`TodoItem`, `TodoListItem`) 어댑터가 채운다.
    - 자식 화면은 플랫폼의 슬롯으로 받는다. Compose는 `child: @Composable () -> Unit`, SwiftUI는 `@ViewBuilder child`, React는 `children`, DOM은 요소다.
    - 입력 중인 텍스트는 순수 뷰가 든다. 테스트 태그와 요소 id도 순수 뷰가 가진다.
  - 모듈이 나뉜 샘플(TodoModular)은 모듈 경계로 강제한다.
    - Android: `:feature:<이름>:ui`는 Compose에만 의존한다. `:feature:<이름>:adapter`를 새로 두어 `:bridge`와 `:ui`에 의존하게 하고, 전체 앱과 그 피처의 demo 앱이 함께 쓴다.
    - iOS: `FeatureXxxUI`는 의존성이 없다(SwiftUI만). `FeatureXxxAdapter`를 새로 두어 `FeatureXxxUI`, `RIBs`, `RIBsSwiftUI`, 자기 Interface에 의존하게 한다.
    - Web: `features/<피처>/view.tsx`(순수 뷰)와 `adapter.tsx`(브리지 구현)로 파일을 나눈다.
  - 모듈이 하나인 샘플(`AndroidLogin`, `iOSLogin`, `WebLogin`)은 패키지·디렉터리로 나눈다(`views/`). 컴파일러가 막아 주지 않으므로 순수 뷰 파일의 import로 확인한다.
  - 라이브러리(`Sources/`)와 브리지 층(ADR-0020), Swift 쪽 화면 객체는 바꾸지 않는다. TodoModular Android의 자리표시 화면(`:bridge`의 `PlaceholderScreen`)은 데모용 발판이라 나누지 않는다.
- 고려했던 대안:
  (1) 현상 유지: 구현이 하나일 때 코드가 가장 짧다. Android 미리보기 불가, 생성 타입 확산, `:ui`의 `:bridge` 의존이 남아 기각했다.
  (2) 순수 뷰가 소유하는 프로토콜을 두고 어댑터가 채택: 뷰가 참조 객체를 쥐어야 할 때만 필요하다. 화면마다 타입이 하나 더 늘어 기본으로 삼지 않는다.
  (3) 라이브러리에 뷰 기반 타입 추가: 코어가 뷰의 모양을 정하게 되어 ADR-0019와 충돌한다. 기각했다.
  (4) TodoModular Android의 어댑터를 `:app`에 두기: 피처별 demo 앱도 같은 어댑터가 필요해 코드가 겹친다. 기각했다.
  (5) TodoModular Android의 어댑터를 `:bridge`에 모으기: `:bridge`가 모든 피처의 `:ui`에 의존하게 되고, demo 앱이 다른 피처의 뷰까지 끌고 온다. 기각했다.
  (6) 순수 뷰가 상태 값 하나를 받기(`LoggedOutView(state:)`): 상태 타입을 순수 뷰 쪽에 다시 정의해야 하고, 공유 코드의 타입과 필드가 같은 타입이 플랫폼마다 생긴다. 인자가 많아지면 다시 검토한다.
- 결과:
  - 순수 뷰는 공유 코드 없이 그려진다. TodoModular Android의 `:feature:<이름>:ui` 계측 테스트 APK에는 Swift 라이브러리가 없고, 뷰 테스트 5개가 그 상태로 통과한다. `AndroidLogin`도 `MainActivity` 없이 뷰만 띄우는 테스트 5개가 통과한다.
  - Compose와 SwiftUI 순수 뷰에 미리보기(`@Preview`, `#Preview`)를 넣었다. Android Studio와 Xcode에서 미리보기가 실제로 뜨는지는 확인하지 않았다. 컴파일과 뷰 단독 테스트만 확인했다.
  - iOS에서 `@Observable` 모델을 어댑터에 두고 순수 뷰에 값으로 넘겨도 갱신된다. 기존 XCUITest 8개가 그대로 통과한다.
  - 기존 UI 테스트는 고치지 않았다. `AndroidLogin`은 `Tags`가 `views` 패키지로 옮겨져 import 한 줄만 더했다.
  - 화면마다 파일이 하나 는다. TodoModular는 피처마다 모듈·타깃이 하나 는다(Android 4개, iOS 4개).
  - 단순한 화면의 어댑터는 값을 그대로 넘기기만 한다.
  - 순수 뷰의 인자 목록은 플랫폼마다 따로 적는다. 상태에 필드를 더하면 어댑터와 순수 뷰를 플랫폼마다 손으로 맞춘다.
  - Android TodoList의 "알림 후 읽기"(ADR-0023)는 어댑터 안에 갇힌다. 순수 뷰는 `List<TodoItem>`만 받는다.
  - TodoModular Android의 `:adapter`는 `:bridge` 전체에 의존하므로 다른 피처의 핸들 타입을 여전히 볼 수 있다. `.so`가 하나인 동안은 그렇다(ADR-0021).
  - ADR-0026의 "`view.tsx`에 화면 컴포넌트와 브리지 구현 클래스를 둔다"는 파일 배치와 이름(`LoggedOutScreen` 컴포넌트, `LoggedOutView` 클래스)은 이 ADR이 대체한다.
  - `new-rib` 템플릿은 아직 뷰 하나만 만든다. 순수 뷰와 어댑터를 따로 만들게 하는 일은 남았다.
- 관련: ADR-0006, ADR-0019, ADR-0020, ADR-0021, ADR-0023, ADR-0024, ADR-0025, ADR-0026
