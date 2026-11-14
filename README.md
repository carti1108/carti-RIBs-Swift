# carti-RIBs-Swift

[uber/RIBs-iOS](https://github.com/uber/RIBs-iOS)를 순수 Swift로 옮긴 크로스플랫폼 RIBs 코어입니다. 자매 프로젝트 carti-RIBs-KMP와 같은 API 모양과 생명주기 순서를 따릅니다.

RIBs-iOS에 없는 확장이 두 가지 있습니다. 루트를 붙였다 떼는 `Router.mount`/`RibMount`, 트리 상태를 저장·복원하는 `RibState`입니다. RIBs-Android와 KMP 판에서 가져왔고, 쓰지 않으면 RIBs-iOS와 같게 동작합니다(ADR-0016).

- Swift 6 언어 모드, 엄격한 동시성, 생명주기 타입은 `@MainActor`
- 최소 툴체인: 호스트(macOS)·Linux는 Swift 6.2 이상. Wasm·Android는 swift.org 툴체인 6.4.2와 해당 Swift SDK(`swift-6.4.2-RELEASE_wasm`, `swift-6.4.2-RELEASE_android`)
- Swift Concurrency만 사용(Rx·Combine 없음). 비동기 작업은 `Interactor.task(_:)`로 활성 구간에 묶음
- 코어 타깃 `RIBs`는 Foundation 없이 표준 라이브러리만 사용 → Linux·Wasm·Android 대상 빌드를 염두에 둠
- 수동 DI(`Component<Dependency>`), 불투명한 `ViewControllable`

## 사용

```swift
.package(url: "<repo-url>", branch: "main")
// target dependencies: ["RIBs"]
```

## 빌드

```sh
swift build
swift test
```

### 공개 API 검사

공개 라이브러리 타깃(`RIBs`, `RIBsSwiftUI`, `RIBsUIKit`, `RIBsWeb`, `RIBsAndroid`)의 API를 `swift-api-digester` 덤프로 `api/`에 체크인해 둡니다(ADR-0011). KMP의 `checkKotlinAbi`/`updateKotlinAbi`와 같은 흐름입니다. macOS·Xcode에서만 돕니다.

```sh
scripts/check-api.sh            # 덤프와 비교. 다르면 깨지는 변경과 diff를 출력하고 실패
scripts/check-api.sh --update   # 공개 API를 의도적으로 바꿨을 때 덤프 갱신(api/를 함께 커밋)
scripts/check-api.sh --baseline <태그>   # 태그가 생긴 뒤: swift package diagnose-api-breaking-changes도 실행
```

`RIBsUIKit`은 iOS 시뮬레이터 SDK로 빌드해 덤프합니다. 덤프 표현은 Xcode의 Swift 버전에 따라 달라질 수 있습니다.

### 문서(DocC)

```sh
swift package generate-documentation --target RIBs --warnings-as-errors
swift package --disable-sandbox preview-documentation --target RIBs   # 로컬 미리보기
```

`Sources/RIBs/RIBs.docc`의 한국어 랜딩 문서가 생명주기, 라우팅, Worker, 상태 저장·복원, 플랫폼 어댑터를 설명합니다. `swift-docc-plugin`은 문서 생성에만 쓰는 의존이라 라이브러리 산출물(Wasm·Android 포함)에 들어가지 않습니다(ADR-0012).

### 플랫폼별 상태

| 플랫폼 | 상태 |
|---|---|
| macOS·iOS | 로컬 빌드·테스트, iOS 샘플 UI 테스트 |
| Linux | Static Linux SDK(musl, x86_64·aarch64)로 `RIBs`·`LoginShared`·`RIBsWeb` 교차 빌드 확인. Linux 호스트가 없어 테스트는 실행하지 않음 |
| Wasm·Android | 6.4.2 Swift SDK 빌드, 웹 E2E·Android 샘플 APK 빌드 |
| Windows | 6.4.2 툴체인으로 `swift build`·`swift test` 통과. Windows 호스트에서 Android `.so` 교차 빌드, x86_64 APK 빌드, 에뮬레이터 계측 테스트 통과 |

## 진행 상황

| 단계 | 내용 | 상태 |
|---|---|---|
| M0 | 패키지 구성, ADR | 완료 |
| M1 | 코어: Interactor, Router, Builder, Component, Worker, LaunchRouter, RibState, KMP 코어 테스트 스위트 이식 | 완료 |
| M2 | 어댑터: `RIBsSwiftUI`(슬롯·호스트), `RIBsUIKit`(`uiviewController`, `UIWindow` 호스트, 컨테이너) | 완료 |
| M3 | `LoginShared` 샘플(Foundation 없음): 로그인·실패·취소, 할 일 목록·상세, 세션 Worker, 테스트 | 완료 (macOS 테스트, Wasm·Android SDK 빌드로 확인) |
| M4 | `RibState` 저장·복원 연결, `new-rib` 스캐폴딩 플러그인, iOS 앱(Tuist)·XCUITest | 완료 (iOS 시뮬레이터 UI 테스트로 확인) |
| M5 | 웹: `RIBsWeb`(화면 슬롯·호스트), Wasm 로그인 샘플(JavaScriptKit DOM), 헤드리스 Chrome E2E | 완료 (호스트 단위 테스트, Puppeteer E2E로 확인) |
| M6 | Android: `RIBsAndroid`(화면 트리 렌더러·슬롯·호스트, 메인 큐↔메인 Looper 연결), 손으로 쓴 JNI + Jetpack Compose 로그인 샘플, 계측 UI 테스트 | 완료 (호스트 단위 테스트, 에뮬레이터 `connectedAndroidTest`로 확인) |
| M7 | 문서·배포 | 완료 |
| M8 | 공개 API 덤프 검사, DocC, 웹 상태 복원 | 완료 |

## 샘플

```sh
swift test --filter LoginSharedTests        # 공유 로직
cd Samples/iOSLogin && tuist generate --no-open
xcodebuild test -workspace LoginSample.xcworkspace -scheme LoginSample \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

## 웹(Wasm)

swift.org 툴체인 6.4.2와 Swift SDK `swift-6.4.2-RELEASE_wasm`, Node.js 22가 필요합니다. 화면은 Swift가 JavaScriptKit으로 DOM을 직접 그립니다(ADR-0009).

```sh
TC=~/Library/Developer/Toolchains/swift-6.4.2-RELEASE.xctoolchain/usr/bin   # Linux는 툴체인 경로의 bin
swift test --filter RIBsWebTests                      # 슬롯 로직(호스트)
cd Samples/WebLogin
$TC/swift package --swift-sdk swift-6.4.2-RELEASE_wasm js   # .build/plugins/PackageToJS/outputs/Package 생성
npm ci                                                # WASI shim, Puppeteer(Chrome 포함)
npm run test:e2e                                      # 헤드리스 Chrome으로 로그인 흐름 확인
python3 -m http.server 8080                           # 브라우저에서 http://localhost:8080 열기
```

`Package.swift`는 루트 패키지를 `.package(name: "RIBs", path: "../..")`로 참조하므로 저장소를 어떤 디렉터리 이름으로 받아도 빌드됩니다(ADR-0015).

`?loginDelayMillis=<ms>`로 로그인 지연을 바꿀 수 있습니다. 상태는 탭의 `sessionStorage`(`ribs.login.savedState`)에 `pagehide`와 `visibilitychange`(hidden) 때 저장되고, 새로고침하면 `LoginApp.start(savedState:)`로 같은 화면(예: 할 일 상세와 완료 여부)이 돌아옵니다(ADR-0013). E2E가 이 새로고침 복원도 확인합니다. 이름을 `fail`로 넣으면 로그인 실패를 확인할 수 있습니다.

## Android

swift.org 툴체인 6.4.2, Swift SDK `swift-6.4.2-RELEASE_android`(NDK r30에 연결), Android SDK(API 37), JDK 21(Android Studio JBR)이 필요합니다. Swift가 화면 트리를 `RibState` JSON으로 그려 JNI로 Kotlin에 넘기고, Compose가 그 JSON을 그립니다. 입력은 `(화면 id, 동작, 인자)`로 Swift에 돌아갑니다. Swift `@MainActor` 작업은 libdispatch 메인 큐를 메인 Looper에 붙여 Android 메인 스레드에서 돕니다(ADR-0010).

```sh
export ANDROID_NDK_HOME=~/Library/Android/android-ndk-r30
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
TC=~/Library/Developer/Toolchains/swift-6.4.2-RELEASE.xctoolchain/usr/bin
swift test --filter RIBsAndroidTests                  # 렌더러·슬롯 로직(호스트)
cd Samples/AndroidLogin
(cd app/src/main/swift && swift test)                 # 화면 객체 + LoginShared 흐름(호스트)
(cd app/src/main/swift && $TC/swift build --swift-sdk aarch64-unknown-linux-android28 --static-swift-stdlib)
./gradlew :app:assembleDebug                          # Swift .so(arm64-v8a) + libc++_shared.so를 APK에 넣음
./gradlew :app:connectedDebugAndroidTest              # 에뮬레이터/기기에서 Compose 로그인 흐름 테스트
```

Gradle은 `SWIFT_CLI`(swift 경로, 기본값은 위 툴체인, 없으면 PATH의 `swift`), `SWIFT_ANDROID_API`(기본 28, `minSdk`와 같음), `-PswiftAbis=arm64-v8a,x86_64`(기본 arm64-v8a)를 받습니다. 인텐트 값 `loginDelayMillis`로 로그인 지연을 바꿀 수 있습니다. `SWIFT_EXEC`는 SwiftPM이 `swiftc` 경로로 읽으므로 `swift`를 넣으면 manifest 컴파일이 깨집니다. 설정하지 마세요.

## Windows

swift.org 툴체인 6.4.2(`winget install Swift.Toolchain --version 6.4.2`), Visual Studio Build Tools 2022(C++ 도구, Windows SDK)가 필요합니다. 의존성 체크아웃에 심볼릭 링크가 있어 **개발자 모드**를 켜야 합니다. 명령은 `vcvars64.bat`를 부른 셸에서 실행하고, 설치 직후 새 환경 변수를 못 받은 셸이면 `SDKROOT`를 직접 잡습니다.

```bat
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
set SDKROOT=%LOCALAPPDATA%\Programs\Swift\Platforms\6.4.2\Windows.platform\Developer\SDKs\Windows.sdk\
swift build && swift test
```

Android도 Windows 호스트에서 빌드됩니다. Swift SDK를 설치한 뒤 번들의 `setup-android-sdk.sh`를 Git Bash에서 복사 모드로 돌려 NDK에 연결합니다. x86_64 PC의 에뮬레이터는 x86_64 ABI로 빌드합니다.

```sh
swift sdk install https://download.swift.org/swift-6.4.2-release/android-sdk/swift-6.4.2-RELEASE/swift-6.4.2-RELEASE_android.artifactbundle.tar.gz \
  --checksum 4d6ad63ea74becd58e123ff58b1b48c3be5ec0db0dff0ea5abe37ac007dd3233
ANDROID_NDK_HOME=$LOCALAPPDATA/Android/Sdk/ndk/30.0.16248370 SWIFT_ANDROID_NDK_LINK=0 \
  bash ~/.swiftpm/swift-sdks/swift-6.4.2-RELEASE_android.artifactbundle/swift-android/scripts/setup-android-sdk.sh
cd Samples/AndroidLogin
gradlew.bat :app:connectedDebugAndroidTest -PswiftAbis=x86_64   # vcvars64 셸, ANDROID_NDK_HOME·JAVA_HOME 설정
```

## Linux(교차 빌드)

macOS에서 swift.org 툴체인 6.4.2와 Static Linux SDK로 Linux용 정적 바이너리 타깃을 빌드합니다. Linux 호스트에서 테스트를 돌린 적은 없습니다.

```sh
TC=~/Library/Developer/Toolchains/swift-6.4.2-RELEASE.xctoolchain/usr/bin
$TC/swift sdk install https://download.swift.org/swift-6.4.2-release/static-sdk/swift-6.4.2-RELEASE/swift-6.4.2-RELEASE_static-linux-0.1.0.artifactbundle.tar.gz \
  --checksum 3786b179936d9cc9e266dd506bd1654176358d7b25288e243359f4d17cc4dc5a
for sdk in x86_64-swift-linux-musl aarch64-swift-linux-musl; do
  for t in RIBs LoginShared RIBsWeb; do $TC/swift build --swift-sdk $sdk --target $t; done
done
```

## 새 RIB 만들기

```sh
swift package --allow-writing-to-package-directory new-rib \
  --name Profile --sources Sources/App --tests Tests/AppTests --module App [--swiftui Sources/AppUI]
```

뷰 계약, Dependency, Listener, Builder, Interactor, Router와 Interactor 테스트, 선택적으로 SwiftUI 화면을 만듭니다. 이미 있는 파일은 덮어쓰지 않습니다.

설계 결정은 [docs/adr](docs/adr/README.md)에 있습니다.
