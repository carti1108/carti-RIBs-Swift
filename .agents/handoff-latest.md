# 🤝 Session Handoff: µFeature 3플랫폼 샘플 (TodoModular)
- **작성 시각 / 브랜치 / 최신 커밋**: `2026-11-23` / `feat/todo-modular-sample` (원격보다 앞섬, 미푸시) / `f04ccd3` 이후
- 이 브랜치는 열린 PR #7(`spike/platform-view-bridge`) 위에 쌓여 있다. ADR-0019~0023은 아직 main에 없다.

## 1. 최종 목표 (Goal)
- Tuist µFeature 모듈화를 이 라이브러리로 iOS·Android·Web에서 보여 주는 샘플 `Samples/TodoModular` (ADR-0024). 기존 `LoginShared`·`iOSLogin`·`AndroidLogin`·`WebLogin`은 그대로 둔다.
- 8단계 계획: 1 ADR → 2 공유 패키지 → 3 경계 검사 → 4 iOS → 5 Android → 6 Web → 7 `NewRib --feature` → 8 `docs/building.md` + 증분 빌드 실측.

## 2. 완료된 작업 (Completed)
- `7ab83b9` ADR-0024, `fa134b4` 공유 패키지, `48fdf73` iOS 4단계, `a77a352` Android 5단계
- `43ae77d`(`spike/platform-view-bridge`) main 병합, README 충돌 해결. `6944bd6`으로 이 브랜치에 병합. **둘 다 미푸시** — 푸시해야 PR #7 충돌이 풀린다.
- #9: `9779808` TodoModular 뷰 계약을 `render(state)`/`handle(action)`으로 전환, `0089a0b` ADR-0025. 기본 Login 샘플(`LoginShared`·`iOSLogin`·`AndroidLogin`·`WebLogin`)도 같은 계약으로 전환.
- #11: `b0fdb38` `Samples/TodoModular/Web` (피처별 `FeatureXxxWeb` 타깃, `features/<피처>/demo.html`, E2E 9개)
- #10: `f04ccd3` 웹 뷰를 React 19·TypeScript·Vite로 전환, ADR-0026. Swift 브리지는 그대로. `WebLogin`은 프레임워크 없는 JS로 남긴다.

## 3. 남은 작업 (Next Steps)
1. 푸시와 이슈 정리(#6·#8·#9·#10·#11 닫기 또는 코멘트): 소유자 확인 후.
2. 3단계 경계 검사: 사용자 결정 대기 (검사 스크립트를 둘지).
3. 7단계 `NewRib --feature`, 8단계 `docs/building.md` 정리(지금은 샘플 README 링크만 있음, TodoModular iOS·Android README 없음)와 증분 빌드 실측.
- 검증 게이트: 루트 `swift build && swift test`, `swift test --package-path Samples/TodoModular/Shared`, Web은 `Samples/TodoModular/Web/README.md`, Android는 아래 5절.

## 4. 핵심 결정 및 막혔던 경로 (Key Decisions & Dead Ends)
- **확정된 결정**:
  - Impl은 자기 Interface, 자식 Interface, `TodoCore`만 import. 조립은 `TodoAppRoot` 하나.
  - 피처별 데모 앱: iOS `FeatureXxxExample`, Android `feature/<f>/demo` (사용자 결정 "안드도 ios 방식").
  - Android `.so`는 하나다 (SwiftJava가 동적 라이브러리 전용). 화면 트리는 kind/id/child만 (ADR-0023).
  - 뷰 계약 이름은 `render`/`handle`. 사용자가 `update`/`request`를 제안했고 유지 이유를 설명함(ADR-0025 대안 5). 사용자의 최종 답은 아직 없다.
  - 기본 샘플과 모듈화 샘플은 따로 둔다(사용자 결정). React는 TodoModular Web에만, 라이브러리는 프레임워크를 모른다.
- **재시도 금지 (Dead Ends)**:
  - `--explicit-target-dependency-import-check error`는 Impl→Impl import를 못 잡는다 (ADR-0024).
  - 파라미터화 `@Test` 인자에서 MainActor static을 읽으면 컴파일 실패 → `nonisolated public static let kind`.
  - zsh `$f:u` 수식어로 경로 만들면 깨진다.
  - 에뮬레이터에 잠금 PIN이 있으면 계측 테스트가 출력 없이 멈춘다 (`is not encryption aware`). 2026-11-23에 `ribs_api37`을 `-wipe-data`로 초기화해 PIN 제거함.
  - `./gradlew connectedDebugAndroidTest`가 멈추면 `adb install` 후 `adb shell am instrument -w com.carti.ribs.samples.todomodular.test/androidx.test.runner.AndroidJUnitRunner`로 직접 실행.
  - 도우미 스크립트는 사용자 승인 없이 만들지 말 것.
  - macOS에는 `timeout` 명령이 없다. 출력을 `grep`으로 거르면 "command not found"가 사라져 빈 결과로 보인다.
  - 이 Mac은 Puppeteer용 Chrome이 내려받아지지 않았다. E2E는 `PUPPETEER_EXECUTABLE_PATH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"`로 돌린다.
  - 테스트 어설션을 고치면 TDD 무결성 훅이 막는다. 계약 변경처럼 불가피하면 사유를 보고하고 승인을 받는다.
- **사용자 맥락**: Swift만 익숙. 답변은 한국어, 짧고 쉽게.

## 5. 워킹 트리 및 테스트 상태
- 미커밋: 이 문서와 `native-ui-decision.md`(이전부터 있던 파일, 건드리지 않음).
- Android 환경: `JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"`, Swift 6.4.2 툴체인, NDK r30 `~/Library/Android/android-ndk-r30`, AVD `ribs_api37`(headless 실행 중일 수 있음).
- Swift 브리지 테스트: `cd Samples/TodoModular/Android/swift && JAVA_HOME=... PATH=<toolchain>/bin:$PATH swift test --disable-sandbox`
