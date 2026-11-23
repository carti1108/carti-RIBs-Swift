# 웹 샘플 (Wasm)

`LoginShared` 트리를 Wasm으로 빌드하고, Swift가 JavaScriptKit으로 DOM을 직접 그립니다(ADR-0009).

swift.org 툴체인 6.4.2와 Swift SDK `swift-6.4.2-RELEASE_wasm`, Node.js 22가 필요합니다.

```sh
TC=~/Library/Developer/Toolchains/swift-6.4.2-RELEASE.xctoolchain/usr/bin   # Linux는 툴체인 경로의 bin
swift test --filter RIBsWebTests                      # 슬롯 로직(호스트, 저장소 루트에서)
cd Samples/WebLogin
$TC/swift package --swift-sdk swift-6.4.2-RELEASE_wasm js   # .build/plugins/PackageToJS/outputs/Package 생성
npm ci                                                # WASI shim, Puppeteer(Chrome 포함)
npm run test:e2e                                      # 헤드리스 Chrome으로 로그인 흐름 확인
python3 -m http.server 8080                           # 브라우저에서 http://localhost:8080 열기
```

`Package.swift`는 루트 패키지를 `.package(name: "RIBs", path: "../..")`로 참조하므로 저장소를 어떤 디렉터리 이름으로 받아도 빌드됩니다(ADR-0015).

- `?loginDelayMillis=<ms>`로 로그인 지연을 바꿀 수 있습니다. 이름을 `fail`로 넣으면 로그인 실패를 확인할 수 있습니다.
- 상태는 탭의 `sessionStorage`(`ribs.login.savedState`)에 `pagehide`와 `visibilitychange`(hidden) 때 저장되고, 새로고침하면 `LoginApp.start(savedState:)`로 같은 화면(예: 할 일 상세와 완료 여부)이 돌아옵니다(ADR-0013). E2E가 이 새로고침 복원도 확인합니다.
