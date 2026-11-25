### ADR-0028 샘플의 모듈 경계는 import 문을 읽는 스크립트로 검사한다
- 상태: 채택
- 날짜: 2026-11-25
- 배경:
  - ADR-0024는 피처 Impl이 자기 Interface, 자식 Interface, `TodoCore`만 import한다고 정했다. ADR-0027은 순수 뷰가 UI 프레임워크만 import한다고 정했다. 둘 다 `Package.swift`·Gradle·Tuist의 의존 선언과 리뷰로만 지켰다.
  - SwiftPM은 한 패키지 안에서 함께 빌드되는 모듈이면 의존을 선언하지 않아도 import가 된다. 그래서 `FeatureLoggedIn`에 `import FeatureTodoList`(다른 Impl)를 넣어도 빌드가 통과한다.
  - `swift build --explicit-target-dependency-import-check error`를 호스트별로 확인했다(일부러 위반을 넣고 종료 코드를 봤다).

    | 조건 | 결과 |
    |---|---|
    | macOS, Xcode Swift 6.4, 기본 빌드 시스템 | 잡는다(종료 코드 1). 공유 패키지와 Android Swift 패키지(다른 패키지의 Impl import 포함) |
    | macOS, swift.org 6.4.2 | 잡는다 |
    | macOS, `--build-system native` | 잡지 못한다 |
    | macOS, `--swift-sdk swift-6.4.2-RELEASE_wasm`(웹 패키지) | 잡지 못한다 |
    | macOS, 웹 패키지 호스트 빌드 | JavaScriptKit의 `JavaScriptEventLoop`이 호스트에서 컴파일되지 않아 쓸 수 없다. `--target`으로 피처 타깃만 빌드하면 통과하지만 위반도 통과한다 |
    | Windows, 6.4.2 | 잡지 못한다(ADR-0024) |

  - 모듈이 하나인 샘플(`AndroidLogin`, `iOSLogin`, `WebLogin`)과 TypeScript·JS 쪽 순수 뷰는 컴파일러가 경계를 막아 주지 않는다(ADR-0027).
- 결정:
  - `scripts/check-sample-boundaries.sh`를 둔다. 소스의 import 문을 읽어 규칙 밖의 import가 있으면 파일과 모듈을 출력하고 1로 끝난다. 빌드하지 않는다. bash, grep, sed만 쓴다.
  - 검사하는 규칙:
    - 공유 패키지의 피처 Impl(`Features/<F>/Sources`): `Feature*` 모듈 가운데 자기 Interface와 자식 Interface만.
    - 피처 Interface(`Features/<F>/Interface`): 자식 Interface만.
    - 플랫폼 피처 타깃(`Feature<F>Android`, `Feature<F>Web`): 자기 Interface만. iOS `Adapter`는 자기 Interface와 자기 UI.
    - 순수 뷰: iOS는 `SwiftUI`만 import. Android `:feature:<이름>:ui`는 `:bridge`에 의존하지 않음. `AndroidLogin`의 `views` 패키지는 브리지·swiftkit을 import하지 않음. 웹 `view.tsx`와 `WebLogin/views`는 자기 디렉터리 밖을 import하지 않음.
  - 자식 Interface 목록은 스크립트에 다시 적지 않는다. `Samples/TodoModular/Shared/Package.swift`의 `feature("…", interfaces: [...])` 줄에서 읽는다.
  - macOS에서는 SwiftPM 옵션을 보조 검사로 쓸 수 있다고 `docs/building.md`에 적는다. 기준은 스크립트다.
- 고려했던 대안:
  (1) SwiftPM 옵션만 쓰기: macOS 호스트 빌드에서만 동작한다. Windows와 웹 패키지에서 검사가 빠지고, Kotlin·TypeScript 쪽 규칙은 다루지 못한다. 기각했다.
  (2) 피처마다 패키지를 따로 두기: 패키지 경계는 SwiftPM이 강제한다. `Package.swift`가 피처 수의 네 배로 늘고 플랫폼 패키지의 의존 선언이 길어진다. 샘플 크기에 비해 무거워 기각했다.
  (3) SwiftSyntax로 import를 파싱하는 도구: 조건부 import나 여러 줄 구문까지 정확하다. 검사 하나에 swift-syntax 빌드가 붙는다. 샘플의 import는 한 줄 한 모듈이라 grep으로 충분해 기각했다.
  (4) 린터(SwiftLint 사용자 규칙 등): 도구 의존이 늘고 Kotlin·TypeScript 규칙은 따로 써야 한다. 기각했다.
- 결과:
  - 일부러 넣은 위반 9건(Impl → Impl, 선언하지 않은 Interface, 플랫폼 타깃 → Impl, 순수 뷰의 공유 코드·브리지 import 등)을 모두 잡았고, 지금 코드에서는 위반이 없다.
  - 어느 호스트에서나 몇 초 안에 돈다. 빌드 산출물과 SDK가 필요 없다.
  - 텍스트 검사라 한계가 있다. `#if` 안의 import, 한 줄에 여러 구문, `@_exported`로 다시 내보낸 모듈은 구분하지 못한다. 지금 샘플에는 없다.
  - `Package.swift`의 `feature(...)` 호출 모양이나 샘플의 디렉터리 배치를 바꾸면 스크립트도 고쳐야 한다. 없는 디렉터리는 위반으로 보고한다.
  - CI가 없어 자동으로 돌지 않는다. 커밋 전에 손으로 돌린다.
- 관련: ADR-0024, ADR-0027
