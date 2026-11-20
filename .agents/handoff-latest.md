# 🤝 Session Handoff: 플랫폼 뷰 브리지 (swift-java · BridgeJS) 적용

- **작성 시각 / 브랜치 / 최신 커밋**: `2026-11-20 18:00` / `spike/platform-view-bridge` / `fe0f1a4` (실험 패키지), 분기점 `bb6ab17` (`docs/adr-snapshot`)
- **작성 환경**: Windows 11. 이어받는 환경은 macOS.

## 1. 최종 목표 (Goal)

- 뷰를 제외한 코드를 Swift 코어로 여러 플랫폼에서 공유한다. 뷰는 각 플랫폼 언어로 쓴다.
- 이번 작업 범위: Android와 Web의 뷰가 Swift가 정의한 뷰 계약을 **타입 있는 호출**로 구현하게 한다. 지금은 Android가 JSON 문자열 키, Web이 Swift DOM 코드다.
- 관련 문서: `docs/adr/ADR-0009-web-via-javascriptkit-dom.md`, `docs/adr/ADR-0010-android-via-jni-and-main-looper.md`, `docs/adr/ADR-0014-android-main-queue-spi-self-check.md`, `docs/adr/ADR-0018-rib-snapshot.md`(제안 상태)
- 사용자가 정한 제약:
  - `ViewState`/`ViewAction`은 코어(`Sources/RIBs`)에서 강제하지 않는다. 샘플의 사용 사례로만 둔다.
  - 웹 뷰의 언어와 프레임워크는 이 레포에서 정하지 않는다.
  - 외부 도구는 공식(swift.org, `swiftlang`)과 비공식을 구분해서 다룬다. swift-java는 공식, JavaScriptKit·BridgeJS·swift-android-native는 비공식이다.

## 2. 완료된 작업 (Completed)

- `fe0f1a4` — 실험 패키지 두 개 추가. 루트 패키지와 `Sources/RIBs`는 변경 없음.
- `Spikes/swift-java-loggedout` — swift-java 0.7.0, JNI 모드, `enableJavaCallbacks`.
  - Linux(Docker `swift:6.4.2`, JDK 21) 호스트 빌드 통과.
  - `java/Main.java`가 `LoggedOutViewBridge`를 구현해 활성화 → 빈 이름 → "carti" 순서의 `render` 3회 값이 기대와 일치(PASS).
  - Linux 호스트에서 `aarch64-unknown-linux-android28`, 릴리스, `--static-swift-stdlib` 크로스 빌드 통과. 산출물은 `libLoginContract.so`와 `libSwiftJava.so` 두 개. 첫 빌드 18분.
- `Spikes/bridgejs-loggedout` — JavaScriptKit 0.63.0의 BridgeJS 플러그인.
  - Linux 호스트에서 `swift-6.4.2-RELEASE_wasm` SDK로 빌드 통과. `bridge-js.d.ts`에 `LoggedOutViewBridge`, `LoggedOutViewState`, `LoggedOutViewActionTag`가 생성됨.
  - `run.mjs`(Node 22)가 같은 시나리오로 PASS.

## 3. 현재 진행 중 & 남은 작업 (In Progress & Next Steps)

1. **실험 패키지를 맥에서 재현**: 아래 5절의 명령으로 두 패키지가 맥에서도 통과하는지 먼저 확인한다.
2. **Android 샘플의 LoggedOut 화면에 적용** (테스트 먼저):
   - 테스트: `Samples/AndroidLogin/app/src/main/swift/Tests/AndroidLoginUITests/AndroidLoginControllerTests.swift`에 브리지 층 테스트 추가.
   - 패키지: `Samples/AndroidLogin/app/src/main/swift/Package.swift`에 swift-java 의존성과 `swift-java.config` 추가. 참고 `Spikes/swift-java-loggedout/Package.swift`.
   - 브리지 층: `Spikes/swift-java-loggedout/Sources/LoginContract/Bridge.swift:4-20`의 `LoggedOutViewBridge`와 `LoggedOutScreenHandle`을 옮긴다. 화면 id로 핸들을 찾는 조회 함수가 추가로 필요하다(지금은 Kotlin이 JSON 트리의 `kind`와 `id`로 화면을 고른다).
   - 교체 대상 Swift: `Samples/AndroidLogin/app/src/main/swift/Sources/AndroidLoginUI/Screens.swift:50-70`의 `LoggedOutScreen`.
   - 교체 대상 Kotlin: `Samples/AndroidLogin/app/src/main/kotlin/com/carti/ribs/samples/swiftandroid/Screens.kt:71`과 `:85-109`.
   - Gradle: `Samples/AndroidLogin/app/build.gradle.kts:63`에 `--disable-sandbox`, `:75-92`의 복사 작업에 `libSwiftJava.so` 추가, 생성된 Java 소스를 소스 세트에 추가, `swiftkit-core` 의존성, R8 keep 규칙.
   - `onMain`(`Bridge.swift:45`)은 실험용이다. `MainActor.assumeIsolated`로 바꾼다. 기존 `JNI.swift`가 같은 방식을 쓴다.
   - 나머지 네 화면(Root, LoggedIn, TodoList, TodoDetail)은 건드리지 않는다.
3. **검증 게이트**: 샘플 패키지 `swift test`, 루트 `swift build && swift test`, 에뮬레이터에서 androidTest 8개(`LoginFlowTest`, `LifecycleRestoreTest`).
4. **Web 샘플의 LoggedOut 화면에 적용**: `Samples/WebLogin/Sources/WebLogin/Screens.swift`를 `Spikes/bridgejs-loggedout/Sources/Facade/main.swift:18-34` 구조로 바꾸고 웹 e2e 5개 실행. 릴리스 Wasm 크기 측정(디버그는 10MB).
5. **ADR 작성**: 두 플랫폼 결과가 나온 뒤. 뷰 계약 모양을 코어에서 강제하지 않는다는 결정, 플랫폼 경계를 화면별 브리지 층으로 둔다는 결정, swift-java·BridgeJS 채택 여부. 채택된 ADR-0009·0010은 고치지 않고 새 ADR로 대체한다.

1단계가 맥에서 막히는 경우의 분기:

| 막힌 곳 | 다음 |
|---|---|
| 메인 스레드(`assumeIsolated` 실패, 작업이 안 돎) | 메인 루퍼 연결을 swift-android-native로 바꿔 재시도 |
| `swiftkit-core`가 minSdk 28에서 안 돎, 또는 R8 | swift-java 보류. 수제 JNI 유지하고 타입만 생성하는 방향 |

## 4. 핵심 결정 및 막혔던 경로 (Key Decisions & Dead Ends)

- **확정된 결정**
  - 경계는 화면마다 "격리 없는 프로토콜 하나 + 핸들 클래스 하나"로 둔다. `@MainActor` 계약은 `internal`로 감춘다.
  - 브리지 프로토콜의 메서드 모양은 화면마다 자유다. `render(state)` 한 개로 통일할 필요가 없다.
  - 코어에는 swift-java·JavaScriptKit 의존성을 넣지 않는다. 샘플 패키지에만 넣는다(ADR-0004).
- **재시도 금지 (Dead Ends)**
  - **뷰 계약을 그대로 내보내기**: `@MainActor` 프로토콜에 대해 두 도구 모두 격리 없는 thunk를 생성해 Swift 6 모드에서 컴파일되지 않는다(swift-java 16건). 다시 시도하지 말 것.
  - **BridgeJS + `AnyObject` 프로토콜**: BridgeJS가 프로토콜마다 `struct Any<이름>` 래퍼를 만들어 클래스 전용 프로토콜을 채택하지 못한다. 실패 형태는 `Spikes/bridgejs-loggedout/AsIs-fails/main.swift`.
  - **swift-java + 프로토콜 상속·프로토콜 반환**: `LoggedOutViewContract`처럼 다른 프로토콜을 상속한 경우와 `any 프로토콜` 반환에서 생성 코드가 잘못 나온다(0.7.0).
  - **Windows 호스트에서 swift-java 빌드**: `SwiftJavaMacros`가 `--static-swift-stdlib`에서 중복 심볼, 옵션을 빼면 `StaticBuildConfigPluginExecutable`이 라이브러리를 찾지 못해 링크 실패. 두 번 실패 후 중단. Windows에서 다시 시도하지 말 것.
  - **Windows 호스트에서 Wasm 크로스 컴파일**: swift.org 문서가 미지원으로 명시.
- **참고 사실**
  - swift-java 빌드에는 `JAVA_HOME`과 `swift build --disable-sandbox`가 필요하다. 플러그인이 내부에서 Gradle을 돌려 `swiftkit-core`를 만든다.
  - swift-java 내부 코드가 `swift_retain` 등 런타임 예약 심볼을 직접 참조한다는 경고가 나온다("앞으로 오류가 된다").
  - JavaScriptKit 주 관리자는 Goodnotes 소속이고, BridgeJS 문서는 "실험 단계, API 안정성 보장 없음"으로 명시한다.

## 5. 워킹 트리 및 테스트 상태

- 미커밋: `native-ui-decision.md`(사용자 초안, 추적 안 함. 커밋하지 않았다).
- 이 PC에서 마지막으로 확인한 것: 루트 `swift build` 통과(PowerShell), Android 샘플 Swift 라이브러리 크로스 빌드 통과(swift-java 없는 현재 상태). 루트 `swift test`와 androidTest는 이번 세션에서 돌리지 않았다.
- `Spikes/bridgejs-loggedout/run.mjs`의 import 경로는 커밋 전에 `/tmp/bbuild/...`에서 `./.build/...`로 바꿨고, 바꾼 뒤에는 다시 실행하지 않았다.

재현 명령(맥, swift.org 6.4.2 툴체인, JDK 21):

```bash
# swift-java
cd Spikes/swift-java-loggedout
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
swift build --disable-sandbox
# 생성 Java: .build/plugins/outputs/swift-java-loggedout/LoginContract/destination/JExtractSwiftPlugin/src/generated/java
# swiftkit-core jar: .build/checkouts/swift-java/SwiftKitCore/build/libs/swiftkit-core-0.7.0.jar
# 위 둘과 java/Main.java를 javac로 컴파일하고, -Djava.library.path=<swift build --show-bin-path>로 Main 실행 → PASS

# BridgeJS
cd Spikes/bridgejs-loggedout
swift package --swift-sdk swift-6.4.2-RELEASE_wasm --allow-writing-to-package-directory js
node run.mjs   # PASS
```

## 새 세션 시작 프롬프트

```
.agents/handoff-latest.md 읽고 3절 1번(실험 패키지 맥 재현)부터 이어서 진행해 줘
```
