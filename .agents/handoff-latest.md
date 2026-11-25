# Session Handoff: #31 마무리 (Mac에서 iOS·Android 확인 → 인수인계 문서 삭제 → PR)
- **작성 / 브랜치 / 기준 커밋**: 2026-11-25 / `feat/web-write-requests` (푸시됨, PR 없음) / `0bc5df0`
- **읽는 사람**: Mac에서 이어 받는 에이전트. 이 문서는 PR을 열기 전에 지운다(3절 3번).

## 1. 목표
이슈 #31(`gh issue view 31`)의 남은 확인을 Mac에서 끝내고, 이 브랜치를 PR로 열어 #31을 닫는다.
Windows·WSL에서 할 수 있는 것은 끝났다(2절). Mac에서만 되는 것만 한다.

## 2. 이미 끝난 것
- #31 1번 웹 전송 계층(쓰기 요청·인증·다른 출처·Problem Details): ADR-0034. Mac에서 Web e2e·iOS `TodoTransportTests`·Android 호스트·계측까지 확인했다(커밋 `074305d`~`d86ca98`).
- Windows 확인(`09262a8`, `9b43dfa`, 기록은 `docs/building.md`의 Windows·WSL·Tauri 절)
  - Windows 호스트: 루트 `swift test` 132개, Shared 72개 통과.
  - swift-java 0.7.0은 Windows 호스트에서 빌드되지 않는다(호스트·Gradle 둘 다). 경로를 `/C:/...`로 넘기는 업스트림 버그, swiftlang/swift-java#920. 패치·fork 하지 않는다.
  - WSL Ubuntu 24.04: 루트 145개(`NewRibTests` 포함), Android Swift 호스트 13개, Web e2e 24개, WebLogin e2e 5개 통과.
  - Tauri(WebView2 158): Wasm 로드, 할 일 목록, 다른 출처 POST·409·PATCH, CORS 거부 시 `unreachable` 확인. 프리플라이트 캐시(5초) 안에서는 CORS 거부여도 POST가 서버에 도착하는 것을 관찰해 기록만 했다.
- #31 2번 플랫폼 입력 브리지(`95071e6`, `215e48b`, `0bc5df0`, 결정은 ADR-0035)
  - 공유 계약: `TodoDetailViewAction.titleCopied(succeeded:)`, `TodoListViewAction.fileReceived(name:text:)`, 두 ViewState에 `notice: String?`(기본값 nil), `TodoStore.add(titles:)`. 파일은 한 번에 100줄까지, 불러오기 전에는 거절.
  - 웹 뷰만 버튼(`#copyTitleButton`)과 파일 자리(`#todoImport`, `#todoImportInput`)를 붙였다. iOS·Android 화면은 고치지 않았다.
  - 검증: Shared 80개(Windows), Web e2e 28개(WSL, 새 `e2e/input-bridge.test.js` 4개 포함), Android Swift 호스트 13개(WSL), 경계 검사.

## 3. 할 일 (순서대로)
1. **iOS 빌드·테스트** — 2번 변경 뒤로 iOS는 한 번도 빌드하지 않았다. 계약 변경은 기본값 있는 필드와 새 액션 케이스뿐이고 iOS 어댑터(`iOS/Features/*/Adapter`)는 기본 이니셜라이저만 쓰며 액션을 `switch`하지 않아 영향이 없다고 봤다. 실제로 확인한다.
   - `Samples/TodoModular/iOS`에서 Tuist로 생성·빌드(`Project.swift`: 앱 `TodoModular`, 피처별 `Feature<이름>Example`, 테스트 `TodoTransportTests`, `TodoModularUITests`).
   - `TodoModularUITests`(XCUITest)와 `TodoTransportTests` 통과 확인. 피처 Example 앱 4개 빌드.
   - 깨지면 고치고 테스트를 먼저 쓴다(`AGENTS.md`).
2. **Android 앱 빌드·계측 테스트** — 2번 변경 뒤 Android는 Swift 호스트 테스트만 돌았다(WSL). Mac에서 `Samples/TodoModular/Android`의 `./gradlew :app:connectedDebugAndroidTest`(에뮬레이터)로 기존 계측 테스트가 그대로 통과하는지 본다.
3. **정리와 PR**
   - 이 문서(`.agents/handoff-latest.md`)를 지우는 커밋: `chore: 병합 전 인수인계 메모 제거`.
   - 1·2번 결과가 `docs/building.md`의 기록과 다르면 고친다.
   - PR은 **소유자 확인 후** 연다(`AGENTS.md`). base `main`, 본문에 `Closes #31`. 커밋 13개 이상, ADR-0034·0035 포함. 검증 항목은 기기·호스트별로 실제 돌린 것만 체크한다.
   - #31 체크박스는 PR 병합 뒤 갱신해도 된다.

## 4. 결정과 막힌 길
- Windows 호스트에서 웹·swift-java 빌드를 고치려고 의존성을 패치하지 않는다. Windows PC는 WSL로 빌드한다(`docs/building.md#wsl에서-빌드`).
- CORS 거부는 `unreachable`로 둔다(ADR-0034). 프리플라이트 캐시 관찰 때문에 분류를 바꾸지 않았다.
- iOS·Android 화면에 클립보드·파일 입력을 붙이는 일은 이번 범위가 아니다(ADR-0035 결과). 하고 싶으면 별도 이슈로.
- CI(#6), 실측(#14), `.so` 분할(#16)은 소유자가 나중에 하기로 했다.

## 5. 작업 트리와 테스트 상태 (작성 시점, Windows)
- 작업 트리 깨끗함. 원격과 같음.
- 마지막 실행: 루트 `swift build && swift test` 132개(Windows), Shared 80개(Windows), Web e2e 28개·Android Swift 호스트 13개(WSL).

## 새 세션 시작 프롬프트
```
git fetch && git switch feat/web-write-requests && git pull 뒤 .agents/handoff-latest.md를 읽고 3절 할 일을 1번부터 진행해. PR은 열기 전에 나한테 확인받아.
```
