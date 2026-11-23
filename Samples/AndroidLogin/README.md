# Android 샘플 (Compose)

화면은 Kotlin(Compose)이 그립니다. 화면 구조(`kind`·`id`·`child`)만 JSON 트리로 넘어오고, 화면 상태와 입력은 swift-java가 만든 타입 있는 브리지(화면별 `XxxViewBridge`·`XxxScreenHandle`)로 오갑니다(ADR-0020, ADR-0021, ADR-0023).

- Swift `@MainActor` 작업은 libdispatch 메인 큐를 메인 Looper에 붙여 Android 메인 스레드에서 돕니다(ADR-0010).
- Swift 6.4.2에는 사용자 정의 메인 실행기 공개 API가 없어 libdispatch SPI를 쓰며, 시작 시 자체검사가 연결이 끊기면 원인을 담아 실패시킵니다(ADR-0014).
- 계측 테스트는 로그인 흐름 외에 구성 변경(회전)과 프로세스 종료 뒤 상태 복원을 확인합니다.

## 요구 사항

swift.org 툴체인 6.4.2, Swift SDK `swift-6.4.2-RELEASE_android`(NDK r30에 연결), Android SDK(API 37), JDK 21(Android Studio JBR).

## macOS에서 빌드

```sh
export ANDROID_NDK_HOME=~/Library/Android/android-ndk-r30
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
TC=~/Library/Developer/Toolchains/swift-6.4.2-RELEASE.xctoolchain/usr/bin
swift test --filter RIBsAndroidTests                  # 렌더러·슬롯 로직(호스트, 저장소 루트에서)
cd Samples/AndroidLogin
(cd app/src/main/swift && swift test)                 # 화면 객체 + LoginShared 흐름(호스트)
(cd app/src/main/swift && $TC/swift build --swift-sdk aarch64-unknown-linux-android28 --static-swift-stdlib)
./gradlew :app:assembleDebug                          # Swift .so(arm64-v8a) + libc++_shared.so를 APK에 넣음
./gradlew :app:connectedDebugAndroidTest              # 에뮬레이터/기기에서 Compose 로그인 흐름 테스트
```

## Windows에서 빌드

[빌드 문서의 Windows 절](../../docs/building.md#windows)대로 툴체인을 준비한 뒤, Swift SDK를 설치하고 번들의 `setup-android-sdk.sh`를 Git Bash에서 복사 모드로 돌려 NDK에 연결합니다. x86_64 PC의 에뮬레이터는 x86_64 ABI로 빌드합니다.

```sh
swift sdk install https://download.swift.org/swift-6.4.2-release/android-sdk/swift-6.4.2-RELEASE/swift-6.4.2-RELEASE_android.artifactbundle.tar.gz \
  --checksum 4d6ad63ea74becd58e123ff58b1b48c3be5ec0db0dff0ea5abe37ac007dd3233
ANDROID_NDK_HOME=$LOCALAPPDATA/Android/Sdk/ndk/30.0.16248370 SWIFT_ANDROID_NDK_LINK=0 \
  bash ~/.swiftpm/swift-sdks/swift-6.4.2-RELEASE_android.artifactbundle/swift-android/scripts/setup-android-sdk.sh
cd Samples/AndroidLogin
gradlew.bat :app:connectedDebugAndroidTest -PswiftAbis=x86_64   # vcvars64 셸, ANDROID_NDK_HOME·JAVA_HOME 설정
```

## Gradle 설정

- `SWIFT_CLI`: swift 경로. 기본값은 위 툴체인, 없으면 PATH의 `swift`
- `SWIFT_ANDROID_API`: 기본 28, `minSdk`와 같음
- `-PswiftAbis=arm64-v8a,x86_64`: 기본 arm64-v8a
- 인텐트 값 `loginDelayMillis`로 로그인 지연을 바꿀 수 있습니다.

`SWIFT_EXEC`는 SwiftPM이 `swiftc` 경로로 읽으므로 `swift`를 넣으면 manifest 컴파일이 깨집니다. 설정하지 마세요.
