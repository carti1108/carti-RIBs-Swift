### ADR-0022 Web 뷰 브리지는 BridgeJS로 생성하고 뷰는 JS가 그린다
- 상태: 채택
- 날짜: 2026-11-20
- 배경:
  - ADR-0009는 Swift가 JavaScriptKit으로 DOM을 직접 그리기로 했고, BridgeJS는 "아직 실험 단계이고 빌드 단계가 늘어난다"는 이유로 대안 (1)에서 기각했다.
  - 목표가 "뷰는 플랫폼 언어로 쓴다"로 정해지면서 Web 뷰도 JS 쪽에 있어야 한다. 웹 뷰의 언어와 프레임워크는 이 레포에서 정하지 않는다.
  - BridgeJS는 JavaScriptKit(0.63.0)에 들어 있는 플러그인이다. `@JS` 선언에서 JS 글루와 TypeScript 타입(`bridge-js.d.ts`)을 만든다. JavaScriptKit은 비공식(`swiftwasm` 조직) 프로젝트이고, BridgeJS 문서는 "실험 단계, API 안정성 보장 없음"이라고 적는다.
  - 실험 패키지(`Spikes/bridgejs-loggedout`)가 통과했고, Web 샘플의 LoggedOut 화면에 적용해 E2E 5개가 통과했다(커밋 `e22cab0`).
- 결정:
  - `Samples/WebLogin`의 타깃에 `BridgeJS` 플러그인을 걸고 실험 기능 `Extern`을 켠다. JavaScriptKit은 이미 `exact: 0.63.0`으로 고정돼 있어 의존성은 늘지 않는다.
  - ADR-0020의 브리지 프로토콜과 핸들 클래스를 `@JS`로 내보낸다. LoggedOut 화면은 Swift가 빈 `<section id="loggedOut">`만 만들고, 안쪽은 `LoggedOutViewBridge`를 구현한 JS 객체가 그린다.
  - 앱은 JS가 시작한다. `index.html`이 `init()` 뒤에 `exports.startLoginApp(new LoggedOutView())`를 부른다. Swift가 로드되면서 스스로 시작하지 않는다.
  - 샘플의 JS 뷰(`views/logged-out-view.js`)는 프레임워크 없이 DOM API로 쓴다. 다른 앱은 같은 프로토콜을 React 등으로 구현하면 된다.
  - 나머지 네 화면은 ADR-0009대로 Swift DOM 코드로 남긴다.
- 고려했던 대안:
  (1) JavaScriptKit의 `JSObject`·`JSClosure`로 손으로 브리지: 플러그인 없이 되지만 JS 쪽 타입이 생기지 않고, 메서드 이름을 문자열로 부르게 된다. 타입 있는 호출이라는 목표와 맞지 않아 기각했다.
  (2) ADR-0009 유지(Swift가 DOM을 그림): 뷰를 플랫폼 언어로 쓴다는 목표와 맞지 않는다. 웹 개발자가 Swift로 DOM 코드를 써야 한다.
  (3) Swift가 화면 상태 저장소를 내보내고 JS가 구독: 저장소 타입을 코어나 `RIBsWeb`에 새로 만들어야 하고, 뷰 계약의 메서드 모양을 상태 하나로 고정하게 된다(ADR-0019와 충돌). 기각했다.
  (4) 뷰 팩토리 프로토콜을 내보내 JS가 화면마다 뷰 객체를 만들어 반환: BridgeJS가 프로토콜 요구 사항의 프로토콜 타입 인자·반환을 지원하지 않는다(JavaScriptKit 문서의 지원 표). 그래서 뷰 객체 하나가 `mount`로 화면 여러 개를 차례로 맡는다.
- 결과:
  - 릴리스 Wasm이 10.16MB에서 10.20MB로 33KB 늘었다(gzip 2.80MB → 2.81MB). 디버그는 11.83MB → 11.89MB다.
  - 빌드 명령은 그대로다(`swift package --swift-sdk <wasm SDK> js`). 플러그인이 같은 단계에서 글루와 `.d.ts`를 만든다.
  - JS 뷰 객체 하나가 LoggedOut 화면 여러 개를 맡으므로, 뷰는 가장 최근에 `mount`한 화면의 요소를 기억해야 한다.
  - 샘플의 JS 뷰는 타입 검사를 받지 않는다. `.d.ts`의 이점을 얻으려면 TypeScript와 빌드 단계가 필요한데, 이 레포는 그것을 정하지 않는다.
  - BridgeJS는 실험 단계라 버전을 올리면 `@JS` 문법이나 생성 코드가 바뀔 수 있다. 버전을 `exact`로 고정하고, 올릴 때 실험 패키지와 E2E로 확인한다.
  - ADR-0009를 대체한다. `RIBsWeb`의 화면 슬롯, JavaScriptKit을 루트 패키지에 넣지 않는 규칙, E2E 구성은 이 ADR이 이어받는다.
- 관련: ADR-0004, ADR-0009, ADR-0013, ADR-0020
