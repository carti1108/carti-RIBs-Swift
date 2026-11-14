### ADR-0014 Android 메인 큐 연결은 libdispatch SPI를 유지하고 시작 시 자체검사한다
- 상태: 채택
- 날짜: 2026-11-14
- 배경: ADR-0010은 `_dispatch_get_main_queue_handle_4CF`·`_dispatch_main_queue_callback_4CF`(libdispatch SPI)로 메인 큐를 메인 Looper에 붙였다. 사용자 정의 메인·전역 실행기 제안(`MainExecutor`, `RunLoopExecutor`, `ExecutorFactory`)으로 공개 API를 쓸 수 있는지 Swift 6.4.2 툴체인에서 다시 확인했다. 기준은 기억이 아니라 SDK에 들어 있는 인터페이스 파일이다: `swift-6.4.2-RELEASE_android.artifactbundle/.../swift_static-aarch64/android/_Concurrency.swiftmodule/aarch64-unknown-linux-android{,.private}.swiftinterface`.
  - 시도 1(공개 API): 공개 `.swiftinterface`에는 `MainExecutor`·`RunLoopExecutor`·`ExecutorFactory`·`MainActor.executor`가 없다. 이를 쓰는 파일을 `swiftc -typecheck -target aarch64-unknown-linux-android28`로 검사하면 `cannot find type 'MainExecutor' in scope`로 실패한다.
  - 시도 2(실험 경로): 이 타입들은 `.private.swiftinterface`에만 `@_spi(ExperimentalCustomExecutors)`로 있다. 설치 함수도 `@_silgen_name("swift_createExecutors") public func _createExecutors<F: ExecutorFactory>(factory:)`라는 밑줄 붙은 SPI다. `@_spi(ExperimentalCustomExecutors) import _Concurrency`로는 Android 대상 타입 검사가 통과하지만, 이것은 지원되는 API가 아니라 다른 실험용 SPI다. 또 제안된 설치 경로는 `@main` 모듈의 `DefaultExecutorFactory`를 컴파일러가 진입점에서 읽는 방식인데, JNI로 로드되는 `.so`에는 `@main`이 없어 손으로 `_createExecutors`를 런타임이 메인 실행기를 처음 쓰기 전에 불러야 한다. 순서를 보장할 방법도 공개돼 있지 않다.
- 결정:
  - Swift 6.4.2에서는 libdispatch SPI 연결을 유지한다. 실험용 사용자 정의 실행기 SPI로 바꾸지 않는다: 위험(비공개 심볼 의존)은 그대로이면서 설치 순서라는 새 위험이 더해진다.
  - 시작 시 자체검사를 둔다.
    1. C `ribs_android_attach_main_queue_to_looper`가 결과 코드(`ribs_android_attach_result`)를 돌려준다. SPI가 준 핸들이 열린 fd인지 `fcntl(F_GETFD)`로 확인한다.
    2. `AndroidMainLooper.attach()`는 실패 원인별 메시지로 `precondition` 실패한다(Looper 없음, SPI 핸들 무효, `ALooper_addFd` 실패). Android 밖에서는 지금처럼 false다.
    3. 성공하면 `Task { @MainActor in }` 하나를 넣어 `AndroidMainLooper.isMainQueueDraining`을 true로 만든다. Kotlin `SwiftBridge`가 2초 뒤 메인 Looper에서 이 값을 확인하고, false면 "libdispatch main queue SPI no longer drains (see ADR-0014)" 메시지로 멈춘다. 계측 테스트 `LifecycleRestoreTest.mainQueueSelfCheckPasses`가 같은 값을 본다.
  - 공개 실행기 API가 Android SDK의 공개 `.swiftinterface`에 들어오면 이 ADR을 대체하는 새 ADR로 `MainExecutor`(ALooper + eventfd/pipe, `ALooper_addFd` 콜백에서 작업 실행) 구현으로 옮긴다.
- 고려했던 대안:
  (1) `@_spi(ExperimentalCustomExecutors)` `MainExecutor` + `_createExecutors`: 위 시도 2의 이유로 기각.
  (2) Kotlin `Handler` 폴링: ADR-0010에서 기각한 이유(지연·배터리) 그대로.
  (3) 자체검사 없이 유지: libdispatch가 바뀌면 `@MainActor` Task가 조용히 멈춘다. 원인을 바로 알 수 있는 실패가 낫다.
- 결과: SPI 의존은 남지만, 깨지면 앱 시작 직후 원인을 담은 메시지로 실패한다. `RIBsAndroid` 공개 API에 `AndroidMainLooper.isMainQueueDraining`이 추가됐다.
- 관련: ADR-0010
