### ADR-0009 웹(Wasm)은 Swift가 JavaScriptKit으로 DOM을 직접 그리고, 화면 슬롯은 순수 Swift 타깃으로 둔다
- 상태: 채택
- 날짜: 2026-11-13
- 배경: 같은 RIB 트리를 브라우저에서 돌려야 한다(M5). carti-RIBs-KMP는 Kotlin이 뷰 계약을 구현해 화면 상태 스냅숏을 `ViewStore`에 담고 React가 `useSyncExternalStore`로 구독한다(KMP ADR-0009). Swift는 swift.org Wasm SDK와 JavaScriptKit으로 브라우저에 올릴 수 있는데, 화면을 누가 그릴지와 어댑터를 어디에 둘지 정해야 한다.
- 결정:
  - `RIBsWeb` 타깃은 `RIBs`에만 의존하고 DOM·JavaScriptKit을 모른다. 자식 화면 하나를 담는 `WebScreenSlot`(`current`, `show`/`hide`, `observe` → `WebSlotSubscription`)과 루트용 `WebViewHost<View>`만 둔다. `RIBScreenSlot`·KMP `ScreenSlot`과 같은 역할이고, 순수 로직이라 macOS·Linux 호스트에서 테스트한다. 플랫폼 가드가 필요 없다.
  - 뷰 계약 구현과 DOM 렌더링은 샘플(`Samples/WebLogin`)의 Swift가 JavaScriptKit으로 직접 한다. 화면 객체는 `DOMScreen`(`element: JSObject`)을 채택하고, `SlotRenderer`가 슬롯을 구독해 지금 화면의 요소만 컨테이너에 붙인다. 공유 코드의 계약(ADR-0006, ADR-0008)은 바꾸지 않는다.
  - JavaScriptKit 의존은 루트 패키지에 넣지 않는다. 샘플은 루트를 경로 의존으로 받는 별도 패키지로 두고, `swift package js`(PackageToJS)로 묶는다. WASI shim은 npm으로 받아 import map으로 연결해 CDN 없이 재현한다.
  - 브라우저 E2E는 Node 내장 `node:test`, 내장 HTTP 서버, Puppeteer(헤드리스 Chrome)로 iOS UI 테스트와 같은 시나리오를 돈다.
- 고려했던 대안:
  (1) KMP처럼 Swift가 화면 상태 저장소를 내보내고 React가 그림: BridgeJS(`@JS` 내보내기)는 아직 실험 단계이고, React·번들러·타입 생성까지 빌드 단계가 늘어난다. 샘플 화면 다섯 개를 그리는 데 비해 비용이 커서 기각했다. 나중에 React 화면이 필요하면 `WebScreenSlot.observe`를 내보내는 방식으로 옮길 수 있다.
  (2) `RIBsWeb`이 JavaScriptKit에 의존해 DOM 렌더러까지 제공: 루트 패키지를 쓰는 모든 호스트 빌드가 JavaScriptKit을 내려받고, `#if os(WASI)` 가드 안 코드는 호스트 테스트가 안 된다. 기각했다.
  (3) Playwright: 브라우저 설치 단계가 따로 필요하다. Puppeteer는 `npm install` 때 Chrome을 받아 단계가 하나 적어 골랐다.
- 결과: `RIBsWeb`은 모든 플랫폼에서 빌드·테스트된다. DOM 코드는 샘플에만 있어 다른 웹 앱은 자기 렌더러를 써야 한다. 샘플 패키지는 루트 패키지를 디렉터리 이름(`carti-RIBs-Swift`)으로 참조하므로 저장소를 다른 이름으로 체크아웃하면 `Package.swift`의 패키지 이름을 맞춰야 한다. 저장 상태 복원은 웹 샘플에 연결하지 않았다.
- 관련: ADR-0004, ADR-0006, ADR-0007, ADR-0008, carti-RIBs-KMP ADR-0009
