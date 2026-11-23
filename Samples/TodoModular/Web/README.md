# TodoModular 웹 앱 (Wasm)

µFeature 샘플(ADR-0024)의 웹 앱입니다. 공유 패키지(`../Shared`)를 Wasm으로 빌드하고, 화면은 피처별 JS 뷰가 그립니다. Swift와 JS는 BridgeJS가 만든 화면별 브리지로 오갑니다(ADR-0020, ADR-0022).

## 구조

| 위치 | 내용 |
|---|---|
| `Sources/FeatureXxxWeb` | 피처의 웹 화면(뷰 계약 구현)과 뷰 팩토리. 자기 Interface만 압니다 |
| `Sources/TodoWebSupport` | DOM 화면 기반 클래스, 루트 화면, 데모용 자리표시 화면 |
| `Sources/TodoModularWeb` | `@JS` 브리지, 전체 앱과 피처별 데모 조립 |
| `features/<피처>/view.js` | 피처의 JS 뷰. 브리지 프로토콜(`XxxViewBridge`)을 구현합니다 |
| `features/<피처>/demo.html` | 그 피처만 띄우는 데모 페이지 |
| `index.html` | 전체 앱 |

`@JS` 선언은 `TodoModularWeb` 한 타깃에만 둡니다. 피처 화면 타깃은 브리지 타입을 모르고, `ViewMounts.swift`가 화면과 JS 뷰를 잇습니다.

## 빌드와 실행

swift.org 툴체인 6.4.2와 Swift SDK `swift-6.4.2-RELEASE_wasm`, Node.js 22가 필요합니다.

```sh
TC=~/Library/Developer/Toolchains/swift-6.4.2-RELEASE.xctoolchain/usr/bin
cd Samples/TodoModular/Web
$TC/swift package --swift-sdk swift-6.4.2-RELEASE_wasm js   # .build/plugins/PackageToJS/outputs/Package 생성
npm ci                                                # WASI shim, Puppeteer
npm run test:e2e                                      # 전체 앱 5개, 피처 데모 4개
python3 -m http.server 8080
```

| 주소 | 화면 |
|---|---|
| `http://localhost:8080/` | 전체 앱 |
| `http://localhost:8080/features/logged-out/demo.html` | 로그아웃 피처 |
| `http://localhost:8080/features/logged-in/demo.html` | 로그인 피처(자식은 자리표시 화면) |
| `http://localhost:8080/features/todo-list/demo.html` | 할 일 목록 피처 |
| `http://localhost:8080/features/todo-detail/demo.html` | 할 일 상세 피처 |

- 데모 페이지는 부모 RIB 대신 받은 이벤트를 화면 아래 `#demoEvent`에 보여 줍니다.
- `?loginDelayMillis=<ms>`로 로그인 지연을 바꿉니다. 이름을 `fail`로 넣으면 로그인이 실패합니다.
- 전체 앱은 상태를 탭의 `sessionStorage`(`ribs.todomodular.savedState`)에 저장하고 새로고침하면 같은 화면으로 돌아옵니다(ADR-0013). 데모 페이지는 저장하지 않습니다.
- `npm ci`가 Chrome을 내려받지 못한 환경에서는 `PUPPETEER_EXECUTABLE_PATH`에 설치된 Chrome 경로를 넣어 E2E를 돌립니다.
