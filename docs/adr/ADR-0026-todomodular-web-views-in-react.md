### ADR-0026 TodoModular 웹 뷰는 React와 TypeScript로 쓰고, 프레임워크는 JS 쪽에만 둔다
- 상태: 채택
- 날짜: 2026-11-23
- 배경:
  - ADR-0022는 웹 뷰를 JS가 그리게 했고, 뷰의 언어와 프레임워크는 정하지 않았다. 샘플(`Samples/WebLogin`)의 뷰는 프레임워크 없이 DOM API로 쓴 JS다.
  - 그 결과 두 가지가 확인되지 않은 채 남았다. 브리지 프로토콜(`mount`/`render`)을 선언형 프레임워크로 구현할 수 있는지, BridgeJS가 만든 `bridge-js.d.ts`가 타입 검사에 실제로 쓰이는지다.
  - `Samples/TodoModular/Web`은 처음에 `WebLogin`과 같은 JS 뷰로 만들었고 E2E 9개(전체 앱 5, 피처 데모 4)가 통과했다. Swift 쪽은 피처별 화면 타깃(`FeatureXxxWeb`)과 브리지 층(`TodoModularWeb`)으로 나뉘어 있다.
  - 이슈 #10은 Swift가 `ViewState`·`ViewAction`과 구독을 내보내고 React가 `useSyncExternalStore`로 받는 안을 제안했다.
- 결정:
  - `Samples/TodoModular/Web`의 뷰를 React 19와 TypeScript로 쓴다. 번들러는 Vite다. 버전은 `package.json`에 정확한 값으로 고정한다.
  - Swift 쪽은 바꾸지 않는다. 브리지 프로토콜, 핸들, `ViewMounts`, 피처 화면 타깃이 그대로다. React·Vite·TypeScript는 이 샘플의 npm 의존성에만 있다. `Sources/RIBs`, `RIBsWeb`, 공유 패키지에는 들어가지 않는다.
  - 피처마다 `features/<피처>/view.tsx`에 두 가지를 둔다.
    - 화면 컴포넌트(`LoggedOutScreen` 등): props로 받은 값만 그린다. Swift와 브리지를 모른다.
    - 브리지 구현 클래스(`LoggedOutView` 등): `mount`에서 `host`에 React 루트를 만들고, `render`에서 받은 인자를 props로 넘겨 다시 그린다. 공통 부분은 `support/react-screen.tsx`의 `ReactScreen`이다.
  - 타입은 BridgeJS가 만든 `bridge-js.d.ts`에서 가져온다(`support/swift.ts`). 브리지 구현 클래스는 `implements XxxViewBridge`로 선언하고, 빌드가 `tsc --noEmit`을 먼저 돌린다.
  - 전체 앱과 피처별 데모를 Vite의 페이지로 따로 빌드한다. 데모 페이지 번들에는 그 피처의 뷰만 들어간다.
  - E2E는 `vite build` 결과(`dist`)를 띄워 돌린다. 요소 id와 시나리오는 JS 뷰일 때와 같다.
  - `Samples/WebLogin`은 프레임워크 없는 JS 뷰로 남긴다. 같은 브리지 방식이 번들러 없이도 되는 예다.
- 고려했던 대안:
  (1) Swift가 `ViewState`·`ViewAction`·구독을 내보내고 React가 `useSyncExternalStore`로 받기(이슈 #10의 안): BridgeJS는 다른 패키지에 있는 타입을 내보내지 못해 상태 타입을 브리지 층에 복제해야 한다(ADR-0020 대안 3). 상태 저장소 타입도 새로 만들어야 한다(ADR-0022 대안 3). `render` 인자를 props로 넘기는 것만으로 React가 그려져 필요가 없었다. 연관 값이 있는 enum과 구독 콜백의 BridgeJS 지원 범위는 확인하지 않았다.
  (2) JS 뷰 유지: 배경의 두 가지가 확인되지 않은 채 남는다. 기각했다.
  (3) `WebLogin`도 React로: 기본 샘플에 npm 빌드 단계가 생긴다. 기본 샘플과 모듈화 샘플을 따로 둔다는 방침에 따라 기각했다.
  (4) 브리지 프로토콜에 `unmount`를 추가: 화면이 내려갈 때 React 루트를 바로 내릴 수 있다. 지금은 같은 종류의 다음 화면이 `mount`될 때 앞 루트를 내린다. 루트는 화면 종류마다 많아야 하나 남고, 이벤트 구독이 없어 새는 것이 없다. 프로토콜을 늘리지 않기로 했다.
- 결과:
  - 브리지 프로토콜을 React로 구현할 수 있음을 E2E 9개로 확인했다. JS 뷰에서 React 뷰로 바꾸는 동안(커밋 `b0fdb38` 대비) Swift 쪽은 주석의 파일 경로만 바뀌었다.
  - `tsc`가 브리지 메서드 이름과 인자 타입을 검사한다. Swift 쪽 `@JS` 선언을 바꾸면 Wasm을 다시 빌드한 뒤 TypeScript 빌드가 어긋난 곳을 알려 준다. `host`는 `.d.ts`에서 `any`라 검사되지 않는다.
  - 빌드 단계가 늘었다. Wasm 빌드 → `tsc` → `vite build` 순서다. `bridge-js.d.ts`가 `.build` 안에 있어 Wasm을 먼저 빌드하지 않으면 타입 검사가 실패한다.
  - 번들에 React 런타임이 들어간다(JS 268KB, gzip 80KB). Wasm은 디버그 빌드로 13MB다.
  - 화면 컴포넌트는 props만 받으므로 Swift 없이 따로 테스트하거나 다른 곳에서 쓸 수 있다. 이 레포는 컴포넌트 단위 테스트를 두지 않는다.
  - React 루트는 같은 종류의 다음 화면이 생길 때까지 남는다(대안 4).
- 관련: ADR-0004, ADR-0013, ADR-0020, ADR-0022, ADR-0024, ADR-0025
