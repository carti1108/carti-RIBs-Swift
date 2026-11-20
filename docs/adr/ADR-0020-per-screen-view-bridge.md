### ADR-0020 플랫폼 뷰 경계는 화면마다 격리 없는 브리지 프로토콜 하나와 핸들 클래스 하나로 둔다
- 상태: 제안
- 날짜: 2026-11-20
- 배경:
  - 목표는 뷰만 플랫폼 언어로 쓰고 나머지를 Swift로 공유하는 것이다. 지금 Android는 화면 상태를 JSON 트리의 문자열 키(`"error"`, `"loading"`)로 읽고 입력을 `(screenId, action, argument)` 문자열로 보낸다(ADR-0010). 키 이름이 틀려도 컴파일러가 잡지 못한다. Web은 뷰까지 Swift가 그린다(ADR-0009).
  - Swift가 정의한 뷰 계약을 Kotlin과 JS가 타입 있는 호출로 구현하게 하려면 바인딩 생성 도구(swift-java, BridgeJS)가 읽을 수 있는 선언이 필요하다.
  - 뷰 계약(`LoggedOutViewContract`)은 `@MainActor`이고 `AnyObject`이며 다른 프로토콜을 상속한다. 실험(`Spikes/`)에서 이 계약을 그대로 내보내면 두 도구 모두 실패했다.
    - `@MainActor` 프로토콜: 두 도구가 격리 없는 thunk를 생성해 Swift 6 언어 모드에서 컴파일되지 않는다(swift-java 오류 16건).
    - `AnyObject` 프로토콜: BridgeJS가 프로토콜마다 `struct Any<이름>` 래퍼를 만들어 클래스 전용 프로토콜을 채택하지 못한다.
    - 프로토콜 상속과 `any 프로토콜` 반환: swift-java 0.7.0이 잘못된 코드를 생성한다.
  - 상태·입력 타입(`LoggedOutViewState`, `LoggedOutViewAction`)은 루트 패키지의 `LoginShared`에 있다. 루트 패키지에는 도구 의존성을 넣을 수 없어(ADR-0004) 이 타입들을 도구가 직접 내보내지 못한다.
- 결정:
  - 플랫폼으로 내보내는 화면마다 샘플 패키지에 브리지 층 파일 하나를 둔다. 안에는 두 가지만 있다.
    - 브리지 프로토콜: 플랫폼 뷰가 구현한다. 격리가 없고(`@MainActor` 아님), 다른 프로토콜을 상속하지 않고, 클래스 전용이 아니다. 예: `LoggedOutViewBridge`.
    - 핸들 클래스: 플랫폼 뷰가 쥐고 입력을 보낸다. 예: `LoggedOutScreenHandle`.
  - `@MainActor` 뷰 계약과 화면 객체는 내보내지 않는다. 브리지 층이 `MainActor.assumeIsolated`로 격리를 확인하고 화면 객체에 넘긴다. 두 플랫폼 모두 호출이 메인 스레드에서 온다(Android는 UI 스레드, Wasm은 단일 스레드).
  - 브리지 프로토콜의 메서드 모양은 화면마다 자유다(ADR-0019). 인자는 도구가 지원하는 기본 타입으로 둔다. LoggedOut은 `render(errorMessage: String?, isLoading: Bool)`과 `loginTapped(rawName: String)`이다. `LoginShared`의 상태·입력 타입을 브리지 쪽에 복제하지 않는다.
  - 브리지 층과 도구 의존성은 샘플 패키지에만 둔다. `Sources/RIBs`, `RIBsAndroid`, `RIBsWeb`, `LoginShared`는 바꾸지 않는다.
  - 뷰와 핸들이 만나는 방법은 플랫폼마다 다르다. Android는 Kotlin이 화면 트리의 `id`로 핸들을 만들어 뷰를 붙인다(`attach`/`detach`). Web은 Swift가 핸들을 만들어 `mount(host:handle:)`로 JS 뷰에 넘긴다. BridgeJS는 프로토콜 메서드가 다른 프로토콜을 주고받는 것을 지원하지 않아 뷰 팩토리 형태를 쓸 수 없다.
  - 한 번에 다 바꾸지 않는다. 지금은 LoggedOut 화면 하나만 이 구조이고, 나머지 네 화면은 ADR-0009·ADR-0010의 방식 그대로다.
- 고려했던 대안:
  (1) 뷰 계약을 그대로 내보내기: 배경의 세 가지 실패 때문에 기각했다. 도구가 `@MainActor`를 지원하게 되면 다시 검토한다.
  (2) 뷰 계약에서 `@MainActor`를 떼기: 생명주기 타입을 `@MainActor`로 둔다는 결정(ADR-0003)과 충돌하고, iOS 어댑터까지 바뀐다. 기각했다.
  (3) 화면마다 `render(state)` 한 개로 통일하고 상태 타입을 브리지 쪽에 복제: 같은 필드를 가진 타입이 `LoginShared`와 브리지 층에 둘 생겨 서로 어긋날 수 있다. 실험 패키지는 이 형태였지만 샘플에 옮기면서 기본 타입 인자로 바꿨다.
  (4) 문자열 키 유지하고 키 상수만 생성(타입 생성기): 도구 의존성 없이 오타를 막을 수 있으나 값의 타입(널 가능 여부, 정수·문자열)은 여전히 런타임에 확인된다. swift-java가 막힐 때의 대체안으로 남긴다.
  (5) 화면 전체를 한 번에 전환: 자식 화면을 담는 RIB(Root, LoggedIn)은 화면 슬롯을 경계 너머로 넘기는 방법이 아직 없다. 화면 하나로 먼저 검증하기로 했다.
- 결과:
  - LoggedOut 화면의 상태와 입력은 두 플랫폼에서 생성된 타입(Java 인터페이스, `bridge-js.d.ts`)으로 오간다. 메서드 이름이나 인자 타입이 어긋나면 Kotlin 컴파일이 실패한다. JS는 타입 검사를 하지 않으므로 `.d.ts`를 쓰려면 뷰를 TypeScript로 써야 한다.
  - Android 화면 트리(JSON)에는 LoggedOut 노드의 `kind`와 `id`만 남는다. 두 방식이 한 앱에 섞여 있다.
  - 브리지 프로토콜과 뷰 계약이 따로 있어, 뷰 계약을 바꾸면 브리지 층도 손으로 맞춰야 한다. 화면이 늘면 이 파일도 화면 수만큼 는다.
  - Android와 Web의 연결 방향이 다르다(핸들을 누가 만드는가). 통일할지는 자식 화면을 담는 RIB을 옮길 때 다시 정한다.
  - `LoggedOutScreenHandle`의 Swift 메모리는 플랫폼 뷰가 관리한다. Android는 `SwiftArena.ofConfined()`를 화면이 컴포지션을 떠날 때 닫고, Web은 `FinalizationRegistry`가 정리한다.
- 관련: ADR-0003, ADR-0004, ADR-0006, ADR-0008, ADR-0009, ADR-0010, ADR-0019, ADR-0021, ADR-0022
