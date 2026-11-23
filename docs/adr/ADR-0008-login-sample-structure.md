### ADR-0008 로그인 샘플을 Foundation 없는 공유 타깃과 플랫폼 앱으로 나눈다
- 상태: 채택 (뷰 계약의 메서드 모양은 ADR-0025로 대체됨)
- 날짜: 2026-11-13
- 배경: carti-RIBs-KMP의 `login-shared`(Root → LoggedOut ⇄ LoggedIn, TodoList/TodoDetail 스택, 세션 Worker, `RibState` 저장·복원)를 옮긴다. 같은 공유 코드가 iOS 앱과 이후 Wasm·Android 앱에서 돌아야 한다.
- 결정:
  - `Samples/LoginShared`는 루트 패키지의 `LoginShared` 라이브러리 타깃이다. `RIBs`와 표준 라이브러리만 쓴다(`import Foundation` 금지). 공백 제거도 `Character.isWhitespace`로 한다.
  - 뷰 계약은 RIB마다 `XxxPresentable`(Interactor → 뷰), `XxxPresentableListener`(뷰 → Interactor), `XxxViewControllable`(Router → 뷰), 이를 합친 `XxxViewContract` 프로토콜이다. 플랫폼은 `LoginViewFactory`로 뷰를 만들어 준다. 리스너는 `AnyObject`라 뷰가 `weak`로 든다.
  - 루트 뷰만 `LoginViewFactory.RootView` 연관 타입이고 `LoginApp<Factory>`가 제네릭이다. `LaunchRouter`·`ViewHost`는 `ViewControllable`을 따르는 구체 타입을 요구하는데 `any RootViewControllable`은 따르지 않기 때문이다. 나머지 RIB은 `ViewableRouter<_, any XxxViewControllable>`로 존재 타입을 쓴다.
  - 시간은 `LoginClock`으로 주입한다. 앱은 `TaskSleepClock`, 테스트는 시간을 직접 넘기는 가짜 시계를 쓴다. `AuthService.signIn`은 취소만 `CancellationError`로 던진다.
  - Interactor가 Router를 `weak var router: (any XxxRouting)?`로 든다(RIBs-iOS 템플릿). KMP의 강한 순환 참조를 피한다.
  - `LoginApp.start(host:savedState:)`는 깨진 저장 문자열이면 트리를 시작하지 않고 `RibStateDecodingError`를 던진다. iOS 앱은 `@SceneStorage`에 저장하고, 실패하면 저장값 없이 다시 시작한다.
  - iOS 앱(`Samples/iOSLogin`)은 Tuist로 생성하며 생성물(.xcodeproj/.xcworkspace)은 커밋하지 않는다.
- 고려했던 대안:
  (1) 샘플을 별도 패키지로 분리: Wasm·Android 빌드 명령(`--target LoginShared`)과 CI가 한 패키지에서 도는 편이 단순해 기각했다.
  (2) 뷰 계약을 클로저 묶음(struct)으로: RIBs-iOS 템플릿·KMP와 모양이 달라지고 스캐폴딩과도 어긋나 기각했다.
  (3) 루트 뷰를 감싸는 박스 클래스: 플랫폼이 다시 꺼내야 해서 연관 타입보다 번거로워 기각했다.
- 결과: 공유 로직은 macOS 테스트(가짜 시계로 실제 대기 없음), Wasm·Android SDK 빌드, iOS 시뮬레이터 UI 테스트로 확인한다. 새 RIB은 `swift package new-rib` 플러그인으로 같은 모양의 뼈대를 만든다.
- 관련: ADR-0003, ADR-0004, ADR-0006, ADR-0007, carti-RIBs-KMP ADR-0006, ADR-0008
