# Session Handoff: #31 Windows 확인 (호스트 테스트, swift-java, WSL 웹 빌드, Tauri WebView2)
- **작성 / 브랜치 / 기준 커밋**: 2026-11-25 / `feat/web-write-requests` (푸시됨, PR 없음) / `d86ca98`
- **읽는 사람**: Windows 호스트에서 이어 받는 에이전트. 이 문서는 작업이 끝나면 지운다(main 병합 전).

## 1. 목표
이슈 #31(`gh issue view 31`) 중 **Windows에서만 확인할 수 있는 것**을 확인하고 결과를 문서에 남긴다.
1. Windows 호스트 `swift test`. 이 브랜치가 더한 `TodoData` 테스트는 Windows에서 돌린 적이 없다.
2. TodoModular Android(swift-java 0.7.0)가 Windows 호스트에서 빌드되는지 **실제로 시도**한다.
3. #31 3번: WSL(Ubuntu)에서 웹 샘플 빌드, Tauri WebView2에서 웹 샘플이 뜨는지.

Mac에서 끝난 것(아래 2절)은 다시 하지 않는다. #31 2번(웹 입력 브리지)은 OS와 무관해 Mac에서 한다. 이 세션 범위가 아니다.

## 2. 이미 끝난 것 (Mac, 이 브랜치)
- #31 1번 웹 전송 계층: 쓰기 요청·`Authorization: Bearer`·다른 출처·Problem Details. 결정과 결과는 `docs/adr/ADR-0034-write-requests-auth-and-problem-details.md`.
  - `074305d` 공유 `TodoData`: `HTTPRequest` 헤더·본문, `BearerTokenTransport`, `ProblemDetails`, `TodoAPIClient.createTodo`
  - `2980365` iOS, `34bb3c3` Android(`start`에 헤더 줄·본문 인자), `612ffb5` Web(+ `spikes/write-request.html`), `44fc5f1` iOS 실제 소켓 테스트
- Mac 검증: Shared `swift test` 전체, Web e2e 24/24, iOS `TodoTransportTests` 12, Android Swift 호스트 13, Android 계측(에뮬레이터) 통과. 앱 안 브라우저에서 다른 출처 가짜 API로 POST·401·409·PATCH·DELETE·CORS 거부도 눈으로 확인.

## 3. 할 일 (순서대로)
1. **Windows 호스트 `swift test`** — 절차는 `docs/building.md:55-63`(vcvars64 셸, `SDKROOT`, 개발자 모드).
   - 레포 루트에서 `swift build && swift test`
   - `Samples/TodoModular/Shared`에서 `swift build && swift test`. 새 테스트는 `Shared/Data/Tests/TodoAPIClientWriteTests.swift`(Problem Details 디코딩, `JSONEncoder` 본문, 401/409). `TodoData`는 `FoundationEssentials`를 쓴다(ADR-0032). JSON 키 순서·이스케이프가 Windows에서 다르면 여기서 깨진다.
   - 결과(통과 개수 또는 실패 메시지)를 `docs/building.md:10`의 Windows 행에 반영한다.
2. **swift-java Windows 빌드 시도** — "Windows에서 swift-java 빌드가 안 된다"는 근거가 레포에 없다. 짐작으로 결론 내지 말고 돌려서 에러를 받는다.
   - Swift 호스트 테스트: `Samples/TodoModular/Android/swift`에서 `swift build`(Mac에서는 `swift test --disable-sandbox`와 `JAVA_HOME` 필요).
   - 앱: `Samples/TodoModular/Android`에서 `gradlew.bat :app:assembleDebug -PswiftAbis=x86_64`. Android SDK 설정은 `Samples/AndroidLogin/README.md:27-38`과 같다(AndroidLogin은 `@_cdecl`이라 swift-java를 안 쓴다. Windows에서 통과한 기록은 그쪽 것뿐이다).
   - 실패하면 첫 에러 줄과 원인(어느 패키지·플러그인·파일:줄)을 `docs/building.md`에 "웹 샘플은 Windows 호스트에서 빌드되지 않는다"(`:67-79`)와 같은 형식의 절로 쓴다. 업스트림(swiftlang/swift-java) 이슈가 있으면 링크한다.
3. **WSL 웹 빌드 (#31 3번, #15)** — `docs/building.md:79`에 "확인하지 않았다"로 남아 있는 항목이다.
   - WSL Ubuntu에 swift.org Linux 툴체인 6.4.2와 Swift SDK `swift-6.4.2-RELEASE_wasm`, Node.js 22 설치.
   - **레포를 WSL 파일 시스템(`~/...`)에 clone**한다. `/mnt/c` 아래는 심볼릭 링크·권한·속도 문제가 생길 수 있다(확인 안 됨, 문제가 나면 기록).
   - `Samples/TodoModular/Web/README.md:24-38` 절차: `swift package --swift-sdk swift-6.4.2-RELEASE_wasm js` → `npm ci` → `npm run build`. 되면 `npm run test:e2e`(Chrome이 없으면 `PUPPETEER_EXECUTABLE_PATH`).
   - 같은 WSL에서 `Samples/TodoModular/Android/swift` 호스트 테스트도 돌려 본다(swift-java는 Linux 지원).
   - 결과를 `docs/building.md:79`에 반영.
4. **Tauri WebView2 (#31 3번)** — 웹 결과물 `Samples/TodoModular/Web/dist/`는 정적 파일이라 Windows에서 Swift를 빌드할 필요가 없다. 3번에서 WSL로 만든 `dist/`를 쓴다.
   - 레포 밖 임시 Tauri 프로젝트에 `dist/`를 넣고 `index.html`(할 일 앱)과 `spikes/write-request.html`이 뜨는지 본다.
   - 확인할 것: Wasm 로드(MIME `application/wasm`), 할 일 목록 화면, Tauri의 출처(`http://tauri.localhost` 등)에서 다른 주소 API로 보내는 쓰기 요청의 CORS·프리플라이트. 스파이크 쿼리 형식은 `Samples/TodoModular/Web/spikes/write-request.ts:2-3`.
   - Tauri 프로젝트 자체는 레포에 넣지 않는다(소유자가 정하지 않음). 결과만 기록한다.
5. **기록** — 결과가 결정을 바꾸면 새 ADR(`docs/adr/README.md` 형식, 대안과 기각 이유 필수). 사실 기록이면 `docs/building.md`. 커밋은 의미 단위, `<type>: <한국어 설명>`. 푸시·PR은 소유자 확인 후(`AGENTS.md`).

## 4. 결정과 막힌 길
- **웹 샘플은 Windows 호스트에서 빌드되지 않는다(확정)**: JavaScriptKit 0.63.0 `PackageToJS` 플러그인이 `stderr`를 Windows에서 import하지 않는다(`docs/building.md:67-79`, swiftwasm/JavaScriptKit#818). `swift build --swift-sdk ..._wasm`도 같은 자리에서 깬다. **Windows 호스트에서 웹 빌드를 다시 시도하지 말 것.** 플러그인 패치·포크도 하지 않는다(레포 밖 의존성 수정).
- swift-java Windows: **미확인**. "안 된다"고 보고하려면 실제 에러 출력이 있어야 한다.
- CORS 거부는 `unreachable`로 둔다(ADR-0034 대안 2). WebView2에서 결과가 달라도 분류를 바꾸지 말고 관찰만 기록한다.
- `check-api.sh`의 `RIBsSwiftUI` 차이는 `main`에서도 나는 기존 문제다. 이 작업과 무관.

## 5. 작업 트리와 테스트 상태 (작성 시점, Mac)
- 커밋 안 된 것: `.claude/launch.json`(Mac 개발 서버 설정, 커밋하지 않음). 그 외 깨끗함.
- 마지막 실행: Shared `swift test` 전체 통과, 루트 `swift test` 통과, iOS `TodoTransportTests` 12 통과.

## 새 세션 시작 프롬프트
```
git fetch && git switch feat/web-write-requests 뒤 .agents/handoff-latest.md를 읽고 3절 할 일을 1번부터 진행해. Windows 호스트에서 웹 빌드는 재시도하지 말고, swift-java는 실제로 돌려서 결과를 기록해.
```
