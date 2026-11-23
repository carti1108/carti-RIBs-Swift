# 🤝 Session Handoff: µFeature 3플랫폼 샘플 (TodoModular)
- **작성 시각 / 브랜치 / 최신 커밋**: `2026-11-23` / `main` / `e3728a5` (이번 작업은 전부 미커밋)

## 1. 최종 목표 (Goal)
- 사용자가 지향하는 Tuist µFeature 모듈화(참고: `C:\Users\user\Desktop\Project\MusicSearch` — 읽기 전용, 수정 금지)를 이 라이브러리로 iOS·Android·Web 3플랫폼에서 보여 주는 새 샘플 `Samples/TodoModular`. 기존 `Samples/LoginShared`·`iOSLogin`·`AndroidLogin`·`WebLogin`은 그대로 둔다(사용자 결정: "새 샘플 추가").
- 결정 근거: `docs/adr/ADR-0024-mufeature-sample-modules.md`. 관련 ADR-0004(Foundation 금지), 0008(로그인 샘플 구조), 0015(`.package(name: "RIBs", path:)`).
- 8단계 계획: 1 ADR → 2 공유 패키지 → 3 경계 검사 → 4 iOS(Tuist) → 5 Android(Gradle) → 6 Web(Vite) → 7 `NewRib` 플러그인 `--feature` 모드 → 8 `docs/building.md` 갱신 + 증분 빌드 실측.

## 2. 완료된 작업 (Completed)
- 1단계: `docs/adr/ADR-0024-mufeature-sample-modules.md`, `docs/adr/README.md`에 0024 행 추가.
- 2단계: `Samples/TodoModular/Shared/` 별도 SwiftPM 패키지(`TodoModularShared`).
  - `Package.swift` — `feature(_:interfaces:)` 헬퍼가 피처마다 Interface/Impl/Testing/Tests 4타깃 생성, 비테스트 타깃마다 library product.
  - `Core/{Sources,Testing,Tests}` — `TodoCore`(Todo, TodoStore, AuthService, `TodoClock`, `package func startTask`), `TodoCoreTesting`(ManualClock, FakeAuthService, `TestParentRouter`, `StubRouter`).
  - `Features/{LoggedOut,LoggedIn,TodoList,TodoDetail}/{Interface,Sources,Testing,Tests}`.
  - `App/{Sources,Tests}` — `TodoAppRoot`(`TodoApp<Factory>`, `TodoAppViewFactory`, `RootViewControllable`, `RootComponent`가 자식 Builder 팩토리 제공).
- 검증: Windows, Swift 6.4.2에서 `swift build --build-tests` 성공, `swift test --package-path Samples/TodoModular/Shared` 6타깃 29테스트 전부 통과.

## 3. 현재 진행 중 & 남은 작업 (Next Steps)
1. **사용자 결정 대기**: 다음 단계 선택(Android/Web 먼저 권장 — Windows에서 검증 가능), 그리고 경계 검사 스크립트 추가 여부.
2. **5단계 Android**: `Samples/AndroidLogin` 구조(`app/src/main/swift/Package.swift`, JNI, ADR-0010)를 본떠 `Samples/TodoModular/Android`. `.so` 하나(TodoAppRoot) + `:feature:*:ui`·`:feature:*:demo`.
3. **6단계 Web**: `Samples/WebLogin`(Package.swift + JavaScriptKit, `e2e/login-flow.test.js`, ADR-0009/0013)을 본떠 `Samples/TodoModular/Web`.
4. **4단계 iOS**: `Samples/iOSLogin/Project.swift`·`Tuist.swift` 참고. 공유 패키지를 로컬 패키지로 받고 `FeatureXxxUI`/`FeatureXxxExample` 타깃. Mac 필요.
- 검증 게이트: `swift test --package-path Samples/TodoModular/Shared` (전체 29개), 레포 루트 `swift build && swift test`(커밋 전 규칙).

## 4. 핵심 결정 및 막혔던 경로 (Key Decisions & Dead Ends)
- **확정된 결정**:
  - Impl은 자기 Interface, 자식 Interface, `TodoCore`만 import. 실제 Impl 연결은 `TodoAppRoot` 하나.
  - 부모는 자식 Builder를 Dependency 메서드로 받음(`LoggedInDependency.makeTodoListBuilder(dependency:)` — `Features/LoggedIn/Interface/LoggedInInterface.swift`).
  - 뷰 팩토리는 피처별로 쪼개고 Builder가 `init(dependency:viewFactory:)`로 받음. Dependency에는 서비스만.
  - 부모가 쓰는 자식 라우팅은 Interface에 프로토콜로 노출: `LoggedInRouting.handleBackPress()`, `TodoDetailRouting.todoID`.
  - 공유 타깃 정의는 SwiftPM(Tuist 아님) — Android·Web이 Tuist를 못 읽음.
- **재시도 금지 (Dead Ends)**:
  - `swift build --explicit-target-dependency-import-check error`는 SwiftPM 6.4.2(Windows)에서 기본(swiftbuild)·`--build-system native` 모두 Impl→다른 Impl import(`FeatureLoggedIn`에 `import FeatureTodoList`)를 잡지 못함. 같은 빌드에 모듈이 있으면 통과. ADR-0024·Package.swift 주석에 반영됨.
  - 검사 스크립트는 레포/사용자 규칙상 사용자 승인 없이 만들지 말 것.
- **사용자 맥락**: Swift만 익숙. MusicSearch는 "내가 지향하는 방식"이지 수정 대상이 아님(한 번 오해해서 교정받음). 답변은 한국어.

## 5. 워킹 트리 및 테스트 상태
```
 M docs/adr/README.md
?? Samples/TodoModular/
?? docs/adr/ADR-0024-mufeature-sample-modules.md
?? native-ui-decision.md   ← 이 작업 이전부터 있던 파일, 건드리지 않음
```
- 마지막 테스트: TodoModularShared 29/29 통과. 레포 루트 `swift build && swift test`는 이번 세션에서 다시 돌리지 않음(루트 파일은 미변경).
- 커밋 안 함. 커밋 규칙: `<type>: <한국어 설명>`, 의미 단위 분리, 푸시·PR은 소유자 확인 후.
