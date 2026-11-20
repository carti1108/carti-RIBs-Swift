### ADR-0021 Android 뷰 브리지는 swift-java(JNI 모드)로 생성하고 Swift 런타임을 동적 라이브러리로 싣는다
- 상태: 채택
- 날짜: 2026-11-20
- 배경:
  - ADR-0020의 브리지 프로토콜과 핸들 클래스를 Kotlin에서 타입 있는 호출로 쓰려면 Java 바인딩이 필요하다. ADR-0010은 swift-java를 대안 (1)로 검토하고 "경계에 오가는 값이 화면 트리 문자열과 입력 세 값뿐"이라는 이유로 기각했다. 화면별 타입 있는 호출을 들이면 그 전제가 바뀐다.
  - swift-java는 `swiftlang` 조직의 공식 프로젝트다. 0.7.0의 JNI 모드와 `enableJavaCallbacks`로 Java 객체가 Swift 프로토콜을 구현할 수 있다.
  - 실험 패키지(`Spikes/swift-java-loggedout`)가 Linux와 macOS 호스트에서 통과했고, Android 샘플의 LoggedOut 화면에 적용해 API 37 에뮬레이터에서 계측 테스트 8개가 통과했다(커밋 `b756c31`).
- 결정:
  - `Samples/AndroidLogin`의 Swift 패키지에 swift-java 0.7.0을 `exact`로 고정해 넣고, `AndroidLogin` 타깃에 `JExtractSwiftPlugin`을 건다. 설정은 `mode: jni`, `enableJavaCallbacks: true`다. 루트 패키지에는 넣지 않는다(ADR-0004).
  - 생성된 Java 소스와 플러그인이 만든 `swiftkit-core-0.7.0.jar`를 Gradle 소스 세트와 의존성에 넣는다. Kotlin 뷰는 생성된 인터페이스를 구현한다.
  - 손으로 쓴 JNI(`JNI.swift`, Kotlin `SwiftBridge`)는 남긴다. 시작·종료·뒤로 가기·상태 저장·메인 Looper 연결과, 아직 옮기지 않은 네 화면의 JSON 트리가 이 경로를 쓴다.
  - `--static-swift-stdlib`를 쓰지 않는다. Swift 런타임은 SDK의 `.so` 12개를 APK에 함께 넣는다. swift-java의 `SwiftJava` 제품이 동적 라이브러리 전용이라 `libAndroidLogin.so`에 묶을 수 없고, 정적 런타임으로 빌드하면 `libSwiftJava.so`가 libdispatch 심볼(`_dispatch_main_q`)을 찾지 못해 `UnsatisfiedLinkError`로 앱이 뜨지 않는다.
  - Kotlin에서 핸들의 메모리는 `SwiftArena.ofConfined()`로 관리한다. 자동 arena는 쓰지 않는다.
- 고려했던 대안:
  (1) 손으로 쓴 JNI에 화면별 함수 추가: 도구 의존성이 없지만 ADR-0010 대안 (2)가 지적한 대로 계약이 늘 때마다 JNI 시그니처와 전역 참조 관리가 는다. Kotlin 쪽 타입도 손으로 맞춰야 해서 기각했다.
  (2) 수제 JNI를 유지하고 Kotlin 타입만 생성: swift-java가 막힐 때의 대체안이다. 지금은 swift-java가 동작하므로 고르지 않았다.
  (3) swift-android-native 등 비공식 바인딩: 공식 도구가 요구를 충족하므로 고르지 않았다. 메인 Looper 연결이 깨질 때의 대체 경로로만 남긴다.
  (4) 정적 런타임 유지: 위 로드 실패 때문에 불가능하다. `.so` 두 개에 런타임이 각각 들어가는 구조라 로드가 되더라도 런타임이 둘이 된다.
- 결과:
  - 네이티브 라이브러리 합계가 10.8MB(`libAndroidLogin.so` 하나)에서 38.6MB(14개)로 늘었다. `libSwiftJava.so`가 10.0MB, `libFoundationEssentials.so`가 10.5MB다. APK 압축 크기는 재지 않았다.
  - 샘플 패키지는 호스트 `swift build`·`swift test`에도 JDK 21(`JAVA_HOME`)과 `--disable-sandbox`가 필요하다. 플러그인이 빌드 중에 Gradle로 `swiftkit-core`를 만든다. macOS에서는 swift.org 툴체인의 `usr/bin`이 `PATH` 앞에 있어야 한다(`/usr/bin/swift`가 먼저 잡히면 플러그인이 `xcrun` 오류로 실패한다).
  - Android arm64 릴리스 크로스 빌드 첫 실행이 6분 32초 걸렸다(8GB Apple Silicon).
  - 확인하지 못한 것: minSdk 28 기기에서 `swiftkit-core`가 도는지(확인한 것은 API 37뿐이다), R8로 축소했을 때 필요한 keep 규칙(샘플은 축소를 켜지 않았다).
  - swift-java 내부 코드가 `swift_retain` 등 런타임 예약 심볼을 직접 참조한다는 경고가 빌드마다 나온다. 컴파일러가 "앞으로 오류가 된다"고 알린다. 또 `JNI.swift`의 `@_cdecl` 함수 8개를 가져오려다 건너뛴다는 경고가 나온다.
  - swift-java는 1.0 전이다. 프로토콜 상속과 `any 프로토콜` 반환에서 잘못된 코드를 생성한다(0.7.0). 버전을 올릴 때는 실험 패키지와 계측 테스트로 다시 확인한다.
  - ADR-0010을 대체한다. 메인 Looper 연결, UTF-8 `byte[]` 규칙, 남은 화면의 JSON 트리는 이 ADR이 이어받는다.
- 관련: ADR-0004, ADR-0010, ADR-0014, ADR-0020
