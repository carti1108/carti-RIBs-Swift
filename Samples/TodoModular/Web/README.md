# TodoModular 웹 앱 (Wasm)

µFeature 샘플(ADR-0024)의 웹 앱입니다. 공유 패키지(`../Shared`)를 Wasm으로 빌드하고, 화면은 피처별 React 뷰(TypeScript)가 그립니다. Swift와 JS는 BridgeJS가 만든 화면별 브리지로 오갑니다(ADR-0020, ADR-0022, ADR-0026).

React·Vite·TypeScript는 이 디렉터리의 npm 의존성에만 있습니다. Swift 쪽(라이브러리, 공유 패키지, 브리지)은 뷰를 무엇으로 만드는지 모릅니다.

## 구조

| 위치 | 내용 |
|---|---|
| `Sources/FeatureXxxWeb` | 피처의 웹 화면(뷰 계약 구현)과 뷰 팩토리. 자기 Interface만 압니다 |
| `Sources/TodoWebSupport` | DOM 화면 기반 클래스, 루트 화면, 데모용 자리표시 화면 |
| `Sources/TodoModularWeb` | `@JS` 브리지, 전체 앱과 피처별 데모 조립 |
| `features/<피처>/view.tsx` | 순수 뷰. props로 받은 값과 콜백만으로 그립니다. Swift 브리지 타입을 모릅니다(ADR-0027) |
| `features/<피처>/adapter.tsx` | 어댑터. 브리지 프로토콜(`XxxViewBridge`)을 구현하고 값을 순수 뷰에 넘깁니다 |
| `features/<피처>/demo.html`, `demo.ts` | 그 피처만 띄우는 데모 페이지 |
| `index.html`, `app.ts` | 전체 앱 |
| `support/` | React 루트를 브리지에 잇는 `ReactScreen`, Wasm 진입점과 생성된 타입 |

`@JS` 선언은 `TodoModularWeb` 한 타깃에만 둡니다. 피처 화면 타깃은 브리지 타입을 모르고, `ViewMounts.swift`가 화면과 웹 뷰를 잇습니다.

## 빌드와 실행

swift.org 툴체인 6.4.2와 Swift SDK `swift-6.4.2-RELEASE_wasm`, Node.js 22가 필요합니다. macOS나 Linux에서 빌드합니다. Windows 호스트에서는 빌드되지 않습니다([이유](../../../docs/building.md#웹-샘플은-windows-호스트에서-빌드되지-않는다)).

```sh
TC=~/Library/Developer/Toolchains/swift-6.4.2-RELEASE.xctoolchain/usr/bin
cd Samples/TodoModular/Web
$TC/swift package --swift-sdk swift-6.4.2-RELEASE_wasm js   # .build/plugins/PackageToJS/outputs/Package 생성
npm ci                                                # React, Vite, TypeScript, WASI shim, Puppeteer
npm run dev                                           # 개발 서버(http://localhost:5173)
npm run build                                         # 타입 검사 뒤 dist/에 빌드
npm run test:e2e                                      # 빌드한 뒤 전체 앱 5개, 피처 데모 4개
```

Wasm을 먼저 빌드해야 합니다. 타입 검사가 `.build` 안의 `bridge-js.d.ts`를 읽습니다. Swift 쪽을 고치면 `swift package ... js`를 다시 돌립니다.

| 주소 | 화면 |
|---|---|
| `http://localhost:5173/` | 전체 앱 |
| `http://localhost:5173/features/logged-out/demo.html` | 로그아웃 피처 |
| `http://localhost:5173/features/logged-in/demo.html` | 로그인 피처(자식은 자리표시 화면) |
| `http://localhost:5173/features/todo-list/demo.html` | 할 일 목록 피처 |
| `http://localhost:5173/features/todo-detail/demo.html` | 할 일 상세 피처 |

- 데모 페이지는 부모 RIB 대신 받은 이벤트를 화면 아래 `#demoEvent`에 보여 줍니다.
- `?loginDelayMillis=<ms>`로 로그인 지연을 바꿉니다. 이름을 `fail`로 넣으면 로그인이 실패합니다.
- 전체 앱은 상태를 탭의 `sessionStorage`(`ribs.todomodular.savedState`)에 저장하고 새로고침하면 같은 화면으로 돌아옵니다(ADR-0013). 데모 페이지는 저장하지 않습니다.
- `npm ci`가 Chrome을 내려받지 못한 환경에서는 `PUPPETEER_EXECUTABLE_PATH`에 설치된 Chrome 경로를 넣어 E2E를 돌립니다.
