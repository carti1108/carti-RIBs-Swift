### ADR-0010 Android는 손으로 쓴 JNI로 화면 트리 JSON을 Compose에 넘기고, 메인 큐를 메인 Looper에 붙인다
- 상태: 채택
- 날짜: 2026-11-13
- 배경: swift.org의 Swift SDK for Android(6.4.2, NDK r30)로 Swift 코드를 Android `.so`로 빌드할 수 있다. 같은 `LoginShared` RIB 트리를 Kotlin/Jetpack Compose 화면으로 그리려면 (1) Swift와 Kotlin 사이 경계, (2) Swift `@MainActor`가 Android 메인 스레드에서 도는 방법이 필요하다. Android용 Swift 런타임의 메인 실행기는 libdispatch 메인 큐인데, Android 앱에서는 `dispatch_main()`도 CFRunLoop도 돌지 않으므로 그대로 두면 `Task { @MainActor in }`(로그인 지연, 세션 타이머)이 영원히 실행되지 않는다.
- 결정:
  - 경계는 손으로 쓴 JNI(`@_cdecl("Java_…")`) 여섯 개 함수다: 메인 Looper 연결, 시작, 입력 전달, 뒤로 가기, 상태 저장, 종료. Kotlin 쪽은 `SwiftBridge` 하나다.
  - 화면은 Swift가 그린다. `RIBsAndroid`의 `AndroidScreen`(뷰 계약을 구현하는 기반 클래스)이 자기 상태를 `[String: RibValue]`로 내놓고, `AndroidRenderer`가 루트부터 트리 전체를 `RibState` JSON 인코딩으로 만들어 Kotlin `SwiftBridge.onRender(byte[])`에 넘긴다. Kotlin은 `org.json`으로 읽어 `kind`별 Composable로 그린다. 입력은 `(screenId, action, argument)` 세 값으로 돌아온다. 문자열은 UTF-8 `byte[]`로 주고받는다(JNI `NewStringUTF`의 수정된 UTF-8은 보조 평면 문자를 깨뜨린다).
  - 메인 실행기: C 타깃 `CRIBsAndroid`가 libdispatch SPI `_dispatch_get_main_queue_handle_4CF()`(Linux·Android에서는 eventfd)를 `ALooper_addFd`로 메인 스레드 Looper에 등록하고, 깨어나면 eventfd를 비운 뒤 `_dispatch_main_queue_callback_4CF`로 메인 큐를 비운다. CoreFoundation이 Linux에서 런루프에 메인 큐를 붙이는 방식과 같다. 라이브러리 로드와 `AndroidMainLooper.attach()`는 반드시 UI(메인) 스레드에서 한다. `ALooper_addFd`는 호출 스레드의 Looper에 등록하기 때문이다. Kotlin `SwiftBridge`는 로드 전에 `Looper.myLooper() == Looper.getMainLooper()`를 확인하고, 아니면 스레드 이름을 담은 메시지로 실패한다. JNI 진입점은 `MainActor.assumeIsolated`로 메인 스레드임을 확인한다(Android UI 스레드는 프로세스의 메인 스레드라 런타임 검사가 통과한다).
  - Swift 런타임은 `--static-swift-stdlib`로 `libAndroidLogin.so`에 넣는다. APK에는 그 파일과 SDK의 `libc++_shared.so`만 들어간다. Gradle `Exec` 작업이 `swift build --swift-sdk aarch64-unknown-linux-android28`을 부른다. Apple Silicon 에뮬레이터는 arm64-v8a라 기본 ABI는 하나이고, `-PswiftAbis=arm64-v8a,x86_64`로 늘릴 수 있다.
  - 샘플의 Swift 패키지(`Samples/AndroidLogin/app/src/main/swift`)는 루트 패키지를 경로 의존성으로 쓴다. 화면 객체(`AndroidLoginUI`)는 JNI 없이 호스트에서 테스트하고, JNI 글루(`AndroidLogin`)만 `#if os(Android)`다.
- 고려했던 대안:
  (1) swift-java JExtract로 Swift 타입을 Java 클래스로 노출: 원본 RIB 객체를 Kotlin에서 직접 다룰 수 있지만, swift-java 빌드 플러그인·JDK 버전·생성 코드가 빌드 경로에 들어오고, 뷰 계약을 Kotlin 객체로 구현하려면 Java 쪽 콜백 프로토콜을 다시 감싸야 한다. 경계에 오가는 값이 화면 트리 문자열과 입력 세 값뿐이라 JNI 함수 여섯 개가 더 단순하고 재현하기 쉬워 기각했다.
  (2) 뷰 계약마다 Kotlin 객체를 만들고 JNI로 메서드를 하나씩 호출: 계약이 늘 때마다 JNI 시그니처가 늘고 전역 참조 수명 관리가 퍼진다. 상태를 한 문자열로 모으면 Kotlin은 순수 렌더 함수가 된다.
  (3) 메인 실행기를 Kotlin `Handler`로 주기적으로 비우기(폴링) 또는 Swift 6.4 사용자 정의 메인 실행기: 폴링은 지연·배터리 비용이 있고, eventfd 등록은 작업이 들어올 때만 깨어난다. 사용자 정의 메인 실행기 API는 아직 플랫폼별 지원이 고르지 않아 libdispatch SPI를 택했다. SPI라서 libdispatch가 바뀌면 깨질 수 있다는 위험을 계측 테스트(세션 타이머가 실제로 증가하는지)로 지킨다.
- 결과: Swift `LoginShared` 트리가 Compose 화면을 전환하고, 로그인 지연·세션 타이머 같은 `@MainActor` Task가 메인 Looper에서 돈다. 화면 트리 전체를 상태가 바뀔 때마다 다시 보내므로 화면이 많아지면 차이만 보내는 방식이 필요할 수 있다. Swift RIB 트리는 프로세스에 하나다(JNI 쪽 전역 상태).
- 관련: ADR-0003, ADR-0006, ADR-0007, ADR-0008
