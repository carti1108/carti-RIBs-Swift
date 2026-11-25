### ADR-0030 상세 화면 전환은 뷰 계약에 의도 이름으로 두고, 사용자가 제스처로 닫은 것은 `ViewAction`으로 알린다
- 상태: 채택
- 날짜: 2026-11-25
- 배경:
  - `TodoModular`의 `LoggedInViewControllable`은 자리 하나에 `showScreen`/`hideScreen`만 있었다(ADR-0025). `LoggedInRouter`는 상세를 열 때 목록 자리에 상세를 갈아 끼우고, 닫을 때 상세를 떼고 목록을 다시 `showScreen`했다.
  - 이 모양으로는 플랫폼의 내비게이션 관례를 쓸 수 없었다. iOS 샘플에 `NavigationStack`이 없어 화면 가장자리에서 미는 뒤로 가기가 안 됐고, Web은 브라우저 뒤로 가기가 페이지를 떠났다.
  - 네이티브 내비게이션을 붙이면 사용자가 공유 코드를 거치지 않고 화면을 닫는 경로가 생긴다. 이를 Router에 알릴 통로가 계약에 없어, 붙이는 순간 화면과 RIB 트리가 어긋난다.
  - 원본 RIBs-iOS는 코어에 내비게이션 API를 두지 않는다. RIB마다 `ViewControllable`에 필요한 메서드를 선언하고, 사용자가 닫으면 뷰가 listener에 알린다(ADR-0001).
- 결정:
  - `LoggedInViewControllable`은 `showList(_:)`, `showDetail(_:)`, `hideDetail(_:)`를 둔다. 이름은 무엇을 보여 줄지만 말한다. 스택에 쌓을지, 시트로 띄울지, 목록 옆에 둘지는 플랫폼 뷰가 정한다.
  - `hideDetail`은 멱등이다. 이미 없는 화면이면 아무 일도 하지 않는다.
  - `LoggedInViewAction`에 `detailDismissedByUser`를 더한다. 뷰는 화면을 먼저 뺀 뒤 이 액션을 보낸다. Interactor는 화면의 닫기 버튼, 시스템 뒤로 가기와 같은 `routeAwayFromDetail`을 탄다. Router가 뒤이어 부르는 `hideDetail`은 멱등이라 아무 일도 하지 않는다. 비활성 상태에서는 이 액션을 무시한다.
  - `routeAwayFromDetail`은 목록을 다시 붙이지 않는다. 목록은 계속 붙어 있고 상세가 그 위에 보였다 사라진다.
  - 코어 `RIBs`는 바꾸지 않는다. 앱 루트(`RootViewControllable`)는 화면을 통째로 바꾸는 자리라 `showScreen`/`hideScreen` 그대로다. ADR-0025의 `render`/`handle`도 그대로이고, 이 ADR은 자식 화면을 붙이는 쪽만 정한다.
  - 플랫폼 구현:
    - iOS: `RIBsSwiftUI`에 `RIBScreenStack`(바닥 화면과 path)과 `RIBStackView`(`NavigationStack(path:)`)를 더한다. SwiftUI가 path 바인딩을 줄이면 빠진 화면을 `onDismissedByUser`로 알린다. `LoggedInView`는 자식이 화면 너비를 다 쓰게 둔다. 스택이 화면 가장자리에 닿지 않으면 가장자리 스와이프가 시작되지 않는다.
    - Web: `LoggedInWebScreen`이 `showDetail`에서 상세마다 토큰을 만들어 `history.pushState`로 항목 하나를 더한다. `popstate`가 왔을 때 `history.state`가 그 토큰이 아니면 상세를 떼고 액션을 보낸다. Router가 닫으면 기록은 건드리지 않고, 남은 항목은 다음 상세가 `replaceState`로 다시 쓴다. 기록 처리는 Swift 화면 객체에 두어 브리지 프로토콜과 React 뷰는 바뀌지 않는다(ADR-0026).
    - Android: `LoggedInAndroidScreen`이 목록과 상세 자리를 따로 들고, 화면 트리의 `child`에는 맨 위 화면만 싣는다. 시스템 뒤로 가기는 지금처럼 `handleBackPress`로 공유 코드를 거치므로 Kotlin에 화면을 직접 닫는 경로가 없다. Kotlin 코드와 화면 트리 모양은 바뀌지 않는다.
- 고려했던 대안:
  (1) 자리 하나를 갈아 끼우는 방식 유지: 스와이프 뒤로 가기와 브라우저 뒤로 가기를 쓸 수 없어 기각했다.
  (2) 코어 `RIBs`에 내비게이션 API 추가: 원본에 없고(ADR-0001), 코어가 뷰의 모양을 정하게 된다(ADR-0019). 기각했다.
  (3) 계약 이름을 `setRoot`/`push`/`pop`으로: 원본 샘플은 UIKit만 대상으로 해 `present`/`push`/`dismiss` 같은 이름을 쓴다. 이 계약은 세 플랫폼이 구현하므로 스택이라는 표현 방식이 공유 계약에 들어간다. 목록과 상세를 나란히 보여 주는 플랫폼에서는 이름과 동작이 어긋난다. 기각했다. `push`/`pop`은 스택으로 그리는 iOS 쪽 도우미(`RIBScreenStack`)에만 쓴다.
  (4) Android 화면 트리에 스택 전체를 싣기: 지금 Compose는 맨 위 화면만 그리므로 쓰는 곳이 없다. 뒤로 가기 제스처 도중 아래 화면을 미리 보여 주는 기능(predictive back)을 넣을 때 다시 검토한다.
  (5) Web에서 Router가 상세를 닫을 때 `history.back()`으로 항목 빼기: `back()`은 비동기라, 닫자마자 다른 상세를 열면 늦게 온 `popstate`가 새 상세를 닫는다. 기록 항목인지 여부를 `history.state` 표시 하나로만 보면 앞으로 가기·새로고침·재로그인 뒤 남은 항목과 구분하지 못한다. 기각했다.
  (6) Web의 기록 처리를 React 어댑터에 두기: 브리지 프로토콜에 메서드가 늘고, 바닐라 JS로 뷰를 다시 쓰면 같은 처리를 또 써야 한다. 기각했다.
- 결과:
  - iOS는 가장자리 스와이프와 내비게이션 바의 뒤로 버튼으로, Web은 브라우저 뒤로 가기로 상세를 닫을 수 있고 RIB 트리가 따라온다. iOS UI 테스트와 Web e2e가 닫은 뒤 다른 상세가 열리는지로 확인한다.
  - 자식 화면이 늘면 `ViewControllable`에 의도 이름 메서드가 는다. 자리 하나짜리 `showScreen`보다 계약이 길어진다.
  - iOS 상세 화면에는 화면 안의 "← 목록" 버튼과 내비게이션 바의 뒤로 버튼이 함께 보인다. 앞의 것은 닫기를 요청하는 경로, 뒤의 것은 사용자가 직접 닫는 경로다.
  - Web에서 화면의 뒤로 버튼이나 로그아웃으로 상세가 닫히면 기록 항목 하나가 남는다. 이때 브라우저 뒤로 가기를 한 번 누르면 화면은 그대로이고 그 항목만 빠진다. 다음 상세는 남은 항목을 다시 써서 기록이 더 늘지 않는다. 앞으로 가기로는 상세가 다시 열리지 않는다.
  - iOS에서 가장자리 스와이프를 도중에 취소하는 경우는 테스트하지 않았다. SwiftUI가 path 바인딩에 쓰지 않으면 알림도 가지 않는다.
  - ADR-0025 결정 가운데 "자식 화면은 `showScreen`/`hideScreen`으로 그대로 둔다"는 `TodoModular`의 LoggedIn에 한해 이 ADR이 대체한다. `render`/`handle`은 그대로다.
  - Android의 뒤로 가기 제스처 미리 보기(predictive back)는 다루지 않는다.
  - `LoginShared`를 쓰는 기본 샘플(iOSLogin, AndroidLogin, WebLogin)은 `showScreen`/`hideScreen` 그대로다.
  - `new-rib` 템플릿(ADR-0029)은 `ViewControllable`을 빈 프로토콜로 만들므로 바뀌지 않는다.
- 관련: ADR-0001, ADR-0019, ADR-0020, ADR-0025, ADR-0026, ADR-0027, ADR-0029
