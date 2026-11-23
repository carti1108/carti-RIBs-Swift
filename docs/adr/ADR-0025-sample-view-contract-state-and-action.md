### ADR-0025 샘플의 뷰 계약은 모두 `render(state)`와 `handle(action)`으로 둔다
- 상태: 채택
- 날짜: 2026-11-23
- 배경:
  - 샘플 RIB 가운데 `LoginShared`의 LoggedOut만 `ViewState`/`ViewAction` 모양이었다(ADR-0019). 나머지(`LoginShared`의 LoggedIn·TodoList·TodoDetail, `TodoModular`의 피처 네 개)는 `showUserName(_:)`, `showTodos(_:)`, `didTapLogout()` 같은 메서드를 화면마다 따로 뒀다(ADR-0008).
  - 메서드가 여러 개면 한 번의 변경이 렌더 여러 번으로 나뉜다. 로그인 실패 응답에서 `showLoading(false)`와 `showError(_:)`가 따로 불려 중간 상태가 화면에 나왔다.
  - Android 화면 객체는 `showUserName`과 `showSessionSeconds`를 합치려고 공유 모듈에 없는 `LoggedInScreenState`, `TodoDetailScreenState`를 따로 만들었다. 같은 필드를 가진 타입이 플랫폼마다 생겼다.
  - `SessionTimerWorker`가 뷰를 직접 불러(`presenter.showSessionSeconds`) 화면에 그려지는 값이 Interactor와 Worker 두 곳에서 나왔다.
  - ADR-0019는 통일을 기각했다. 자식 화면을 담는 RIB(Root, LoggedIn)의 `showScreen`/`hideScreen`이 상태 값으로 표현되지 않는다는 이유였다.
- 결정:
  - 샘플(`LoginShared`, `TodoModular`)의 모든 RIB은 `XxxPresentable`에 `render(_ state: XxxViewState)` 하나, `XxxPresentableListener`에 `handle(_ action: XxxViewAction)` 하나를 둔다.
    - `XxxViewState`는 `Equatable`, `Sendable`인 struct다. 화면에 그릴 값 전체를 담는다.
    - `XxxViewAction`은 `Equatable`, `Sendable`인 enum이다. case 이름은 일어난 일로 짓는다(`loginTapped(rawName:)`, `todoTapped(id:)`).
  - 자식 화면을 붙이고 떼는 일은 상태에 넣지 않는다. `XxxViewControllable`의 `showScreen`/`hideScreen`으로 그대로 둔다. `render`는 Interactor → 뷰, `showScreen`은 Router → 뷰로 부르는 쪽이 다르다. ADR-0019가 든 문제는 이 구분으로 피한다. Root는 `Presentable`이 없어 바뀌지 않는다.
  - 화면 상태는 Interactor만 만든다. Worker는 뷰를 부르지 않고 Interactor에 알린다(`SessionTimerListener.sessionDidTick(seconds:)`).
  - 비활성화될 때 Interactor는 취소된 작업이 남긴 값(로딩)을 상태에서 지운다. 다시 붙으면 `render`로 현재 상태를 한 번 그린다.
  - 플랫폼 화면 객체는 공유 모듈의 `XxxViewState`를 그대로 든다. 플랫폼용 상태 타입을 따로 만들지 않는다.
  - 플랫폼 경계(브리지 프로토콜과 핸들, ADR-0020)는 바꾸지 않는다. 브리지의 `render(...)`는 기본 타입 인자를 받고, 핸들은 액션마다 메서드 하나를 둔다. Swift 화면 객체가 `XxxViewState`를 인자로 풀고, 핸들 호출을 `XxxViewAction`으로 묶는다.
  - 라이브러리(`Sources/RIBs`와 어댑터)는 바꾸지 않는다. 뷰 계약의 모양을 강제하지 않는다는 ADR-0019의 결정은 유지한다. `new-rib` 템플릿도 메서드 없는 빈 계약을 그대로 만든다.
- 고려했던 대안:
  (1) 지금처럼 화면마다 고르게 두기(ADR-0019의 결과): 샘플이 "권장하는 모양"을 보여 주지 못하고, 배경의 세 문제(나뉜 렌더, 플랫폼별 상태 타입, Worker의 직접 호출)가 남아 기각했다.
  (2) 라이브러리에 `ViewState`/`ViewAction` 프로토콜을 두고 강제: 연관 타입 때문에 `any XxxPresentable` 사용이 번거로워지고 원본에 없는 API가 는다(ADR-0001, ADR-0019). 기각했다.
  (3) 자식 화면 슬롯까지 상태에 넣기: `ViewControllable`은 불투명한 참조라(ADR-0006) `Equatable`·`Sendable` 값에 담을 수 없고, Router가 할 일을 Interactor가 하게 된다. 기각했다.
  (4) 브리지 프로토콜도 `render(state)` 한 개로 바꾸기: swift-java와 BridgeJS는 다른 패키지의 타입을 내보내지 못해 상태 타입을 브리지 쪽에 복제해야 한다(ADR-0020 대안 3). 연관 값이 있는 enum의 지원 범위도 확인되지 않았다. 웹 뷰를 TS 프레임워크로 옮길 때 다시 검토한다.
  (5) 메서드 이름을 `update(_:)`/`request(_:)`로: `update`는 일부만 고친다는 뜻으로 읽히고 Interactor 안의 상태 갱신 함수와 이름이 겹친다. `request`는 자식 → 부모 의도(`didRequestLogout`, `didRequestCloseDetail`)에 이미 쓰고 있어 방향이 섞인다. 기각했다.
- 결과:
  - 한 번의 변경은 한 번의 `render`다. 로그인 실패는 오류와 로딩 해제가 한 상태로 그려지고, 테스트가 렌더 횟수로 확인한다.
  - 가짜 뷰는 받은 상태를 배열로 모으기만 한다. 테스트는 `XxxViewState` 값을 통째로 비교한다.
  - 뷰 입력이 늘면 `XxxViewAction`에 case를 더한다. Interactor의 `switch`가 빠진 case를 컴파일 오류로 알려 준다.
  - 값이 하나만 바뀌어도 상태 전체가 넘어간다. 세션 시간이 1초마다 바뀌면 사용자 이름도 함께 다시 넘어간다. 지금 화면 크기에서는 비용이 보이지 않는다.
  - 브리지 층에는 상태를 인자로 푸는 코드와 액션으로 묶는 코드가 화면마다 남는다. 상태에 필드를 더하면 브리지 프로토콜과 Kotlin·JS 뷰도 손으로 맞춰야 한다.
  - ADR-0008의 뷰 계약 설명 중 메서드 모양, ADR-0019의 "샘플에 두 가지 스타일이 섞여 있다"는 결과와 대안 (2)의 기각은 이 ADR이 대체한다.
- 관련: ADR-0001, ADR-0006, ADR-0008, ADR-0019, ADR-0020, ADR-0023, ADR-0024
