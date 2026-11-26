# 빌드와 검증

## 플랫폼별 상태

| 플랫폼 | 상태 |
|---|---|
| macOS·iOS | 로컬 빌드·테스트, iOS 샘플 UI 테스트. CI에서 매번 검사([아래](#ci)) |
| Linux | Static Linux SDK(musl, x86_64·aarch64)로 `RIBs`·`LoginShared`·`RIBsWeb` 교차 빌드 확인. WSL Ubuntu 24.04에서 루트 `swift test`(145개, `NewRibTests` 포함), TodoModular Android Swift 호스트 테스트(13개), 웹 샘플 빌드와 e2e 통과(2026-11-25, [아래](#wsl에서-빌드)) |
| Wasm·Android | 6.4.2 Swift SDK 빌드, 웹 E2E·Android 샘플 APK 빌드와 에뮬레이터 계측 테스트. CI에서 매번 검사([아래](#ci)) |
| Windows | 6.4.2 툴체인으로 루트 `swift build`·`swift test`(132개), `Samples/TodoModular/Shared`의 `swift build`·`swift test`(72개) 통과(2026-11-25). 웹 샘플은 빌드 불가([아래](#웹-샘플은-windows-호스트에서-빌드되지-않는다)). swift-java를 쓰는 Android 샘플도 빌드 불가([아래](#swift-java를-쓰는-android-샘플은-windows-호스트에서-빌드되지-않는다)) |

## CI

`.github/workflows/ci.yml`이 `main` 푸시와 PR마다 돕니다. `changes` 잡이 바뀐 경로를 보고 필요한 잡만 돌립니다.

| 잡 | 러너 | 검사 | 도는 경로 |
|---|---|---|---|
| `boundaries` | Ubuntu | 샘플 모듈 경계(`scripts/check-sample-boundaries.sh`), `Sources/RIBs` import 제한(ADR-0004) | `Samples/**` |
| `linux` | `swift:6.4.2` 컨테이너 | 루트와 `Samples/TodoModular/Shared`의 `swift build`·`swift test` | `Tests/**`, `Samples/LoginShared/**`, `Samples/TodoModular/Shared/**` |
| `macos` | macOS | 루트 `swift build`·`swift test`, 공개 API 검사 | `Tests/**`, `Samples/LoginShared/**`, `api/**`, `scripts/check-api.sh` |
| `web` | Ubuntu 24.04 | TodoModular 웹과 WebLogin의 Wasm 빌드, e2e | 공유 코드, 두 웹 샘플 |
| `ios` | macOS | TodoModular·iOSLogin UI 테스트, `URLSession` 전송 테스트, 피처 Example 앱 빌드 | 공유 코드, 두 iOS 샘플 |
| `android` | Ubuntu 24.04 | TodoModular Swift 호스트 테스트, 두 앱의 APK 빌드, API 35 x86_64 에뮬레이터 계측 테스트 | 공유 코드, 두 Android 샘플 |

- "공유 코드"는 `Samples/LoginShared/**`와 `Samples/TodoModular/Shared/**`입니다.
- `.github/**`, `Package.swift`, `Sources/**`, `Plugins/**`가 바뀌면 모든 잡이 돕니다.
- 문서(`docs/**`, `*.md`)만 바뀌면 `changes` 잡 하나로 끝납니다.
- iOS UI 테스트는 실패한 테스트만 한 번 더 돌립니다(`-retry-tests-on-failure -test-iterations 2`). 두 번 다 실패하면 잡이 실패하고 `.xcresult`를 아티팩트로 올립니다.
- Android 잡은 Swift 교차 빌드 결과(`.build`)를 캐시합니다. 깨끗한 빌드 시간의 대부분이 swift-java·swift-syntax 같은 의존성 컴파일이기 때문입니다([증분 빌드](#µfeature-샘플의-증분-빌드)).
- 웹 잡은 Puppeteer의 Chrome이 root로 뜨지 않아 컨테이너 대신 러너에 툴체인을 설치합니다(`.github/actions/setup-swift-linux`).

## 공개 API 검사

공개 라이브러리 타깃(`RIBs`, `RIBsSwiftUI`, `RIBsUIKit`, `RIBsWeb`, `RIBsAndroid`)의 API를 `swift-api-digester` 덤프로 `api/`에 체크인해 둡니다(ADR-0011). macOS·Xcode에서만 돕니다.

```sh
scripts/check-api.sh            # 덤프와 비교. 다르면 깨지는 변경과 diff를 출력하고 실패
scripts/check-api.sh --update   # 공개 API를 의도적으로 바꿨을 때 덤프 갱신(api/를 함께 커밋)
scripts/check-api.sh --baseline <태그>   # 태그가 생긴 뒤: swift package diagnose-api-breaking-changes도 실행
```

`RIBsUIKit`은 iOS 시뮬레이터 SDK로 빌드해 덤프합니다. 덤프 표현은 Xcode의 Swift 버전에 따라 달라질 수 있습니다.

## 문서(DocC)

```sh
swift package generate-documentation --target RIBs --warnings-as-errors
swift package --disable-sandbox preview-documentation --target RIBs   # 로컬 미리보기
```

`Sources/RIBs/RIBs.docc`의 한국어 랜딩 문서가 생명주기, 라우팅, Worker, 상태 저장·복원, 플랫폼 어댑터를 설명합니다. `swift-docc-plugin`은 문서 생성에만 쓰는 의존이라 라이브러리 산출물(Wasm·Android 포함)에 들어가지 않습니다(ADR-0012).

## 샘플

샘플별 빌드·실행 절차는 각 README에 있습니다.

- 기본 샘플: [iOS](../Samples/iOSLogin/README.md), [Android](../Samples/AndroidLogin/README.md), [Web](../Samples/WebLogin/README.md)
- µFeature 샘플(`Samples/TodoModular`, ADR-0024): [개요](../Samples/TodoModular/README.md), [iOS](../Samples/TodoModular/iOS/README.md), [Web](../Samples/TodoModular/Web/README.md), [Android](../Samples/TodoModular/Android/README.md)

### 웹 샘플의 Wasm 크기

`swift package ... js`는 기본이 디버그 빌드입니다. 배포 크기는 `-c release`로 잽니다. `wasm-opt`(binaryen)가 PATH에 있으면 PackageToJS가 최적화에 씁니다(`--no-optimize`로 끔).

2026-11-26, macOS, swift.org 툴체인 6.4.2, Swift SDK `swift-6.4.2-RELEASE_wasm`, JavaScriptKit 0.63.0, binaryen 133. gzip은 `-9`, brotli는 `-q 11`.

| 산출물 | 구성 | 압축 전 | gzip | brotli |
|---|---|---|---|---|
| `TodoModularWeb.wasm` | 디버그 | 22.8MB | 6.3MB | 측정 안 함 |
| `TodoModularWeb.wasm` | 릴리스 + `wasm-opt` | 8.5MB | 3.0MB | 2.2MB |
| `WebLogin.wasm` | 릴리스 + `wasm-opt` | 4.1MB | 1.5MB | 1.1MB |

- 웹 서버는 `.wasm`을 brotli나 gzip으로 압축해 보내야 합니다. 압축하지 않으면 릴리스도 8.5MB를 받습니다.
- WebLogin은 Foundation을 쓰지 않습니다. TodoModular는 데이터 계층(`TodoData`)이 `FoundationEssentials`를 씁니다(ADR-0032). 두 샘플의 차이(압축 전 4.4MB) 중 얼마가 `FoundationEssentials`인지는 나눠 재지 않았습니다.

```sh
TC=~/Library/Developer/Toolchains/swift-6.4.2-RELEASE.xctoolchain/usr/bin
brew install binaryen brotli
$TC/swift package --swift-sdk swift-6.4.2-RELEASE_wasm js -c release
W=.build/plugins/PackageToJS/outputs/Package/TodoModularWeb.wasm
stat -f%z $W; gzip -9c $W | wc -c; brotli -c -q 11 $W | wc -c
```

### µFeature 샘플의 증분 빌드

TodoModular에서 한 곳을 고쳤을 때 무엇이 다시 컴파일되는지 플랫폼별로 쟀습니다(#14).

2026-11-26, Apple M1(8코어), Xcode 27.0, swift.org 툴체인 6.4.2, Android Studio JBR 25, Gradle 9.7.1.

| 플랫폼 | 빌드 명령 | 구성 |
|---|---|---|
| 공유 패키지 | `Samples/TodoModular/Shared`에서 `swift build` | 디버그, Xcode의 Swift |
| Web | `swift package --swift-sdk swift-6.4.2-RELEASE_wasm js` 뒤 `npm run build` | 디버그, swift.org 6.4.2 |
| iOS | `xcodebuild build -scheme TodoModular`(시뮬레이터) | 디버그 |
| Android | `./gradlew :app:assembleDebug -PswiftAbis=arm64-v8a` | Swift는 릴리스(Gradle이 `-c release`로 부름), swift.org 6.4.2 |

시나리오:

- **구현**: `FeatureTodoDetail` 안의 내부 문자열 하나를 바꿈
- **Interface**: `FeatureTodoDetailInterface`에 쓰지 않는 공개 타입 하나를 더함
- **코어**: `TodoCore`의 샘플 데이터 문자열 하나를 바꿈(공개 API는 그대로)

시간(초, 괄호 안은 다시 컴파일된 Swift 모듈 수):

| 플랫폼 | 깨끗한 빌드 | 변경 없음 | 구현 | Interface | 코어 |
|---|---|---|---|---|---|
| 공유 패키지 | 12 (17) | 1 (0) | 2 (2) | 3 (7) | 2 (16) |
| Web | 74 (28) | 3 (0) | 4 (3) | 7 (10) | 6 (21) |
| iOS | 38 (23) | 14 (0) | 14 (1) | 16 (7) | 16 (6) |
| Android | 531 (32) | 20 (0) | 11 (1) | 15 (1) | 16 (1) |

다시 컴파일된 모듈:

| 플랫폼 | 구현 | Interface | 코어 |
|---|---|---|---|
| 공유 패키지 | `FeatureTodoDetail`, `TodoAppRoot` | TodoDetail 3개(Impl·Interface·Testing), LoggedIn 3개, `TodoAppRoot` | 공유 패키지 모듈 전부(17개 중 16개, `RIBs` 제외) |
| Web | `FeatureTodoDetail`, `TodoAppRoot`, `TodoModularWeb` | 공유 패키지와 같은 7개 + `FeatureTodoDetailWeb`, `FeatureLoggedInWeb`, `TodoModularWeb` | 공유 모듈 전부와 웹 모듈 전부(21개) |
| iOS | `FeatureTodoDetail` | `FeatureTodoDetail`, `FeatureTodoDetailInterface`, `FeatureTodoDetailAdapter`, `FeatureLoggedIn`, `FeatureLoggedInInterface`, `TodoAppRoot`, 앱 `TodoModular` | `TodoCore`, `FeatureTodoDetail`, `FeatureTodoDetailInterface`, `FeatureTodoList`, `FeatureTodoListInterface`, `FeatureLoggedIn` |
| Android | `FeatureTodoDetail` | `FeatureTodoDetailInterface` | `TodoCore` |

- 피처 구현만 고치면 많아야 그 피처와 그것을 조립하는 루트(공유 패키지·Web)만 다시 컴파일한다. 다른 피처는 어느 플랫폼에서도 건드리지 않는다.
- Interface를 고치면 공유 패키지·Web·iOS는 그 Interface를 import하는 부모 피처(LoggedIn)까지 다시 컴파일한다. 형제 피처(TodoList, LoggedOut)는 그대로다. Android는 Interface 모듈 하나만 다시 컴파일했다.
- 공유 패키지와 Web(디버그, SwiftPM)은 공개 API가 그대로여도 `TodoCore`를 고치면 그 위의 모듈을 모두 다시 컴파일했다. 같은 수정에 iOS(Xcode)는 6개, Android(Swift 릴리스)는 `TodoCore` 하나만 다시 컴파일했다. 빌드 시스템마다 모듈 경계를 넘는 증분 판단이 다른 것으로 보이며, 원인은 확인하지 않았다.
- 샘플이 작아 시간 차이는 몇 초다. iOS의 "변경 없음" 14초와 Android의 20초는 컴파일이 아니라 `xcodebuild`·Gradle 자체의 고정 비용이다.
- Android 깨끗한 빌드 531초의 대부분은 swift-java와 swift-syntax 같은 의존성 컴파일이다. CI는 이 부분을 캐시한다.

측정 방법:

- 시나리오마다 고치고 빌드한 뒤 되돌리고 다시 빌드해, 다음 시나리오가 같은 상태에서 시작하게 했다.
- 모듈 목록: 공유 패키지는 `swift build -v`의 `-module-name`, iOS는 `xcodebuild` 로그의 `SwiftCompile ... (in target '…')`, Web·Android는 빌드가 새로 쓴 `.o` 파일의 모듈 디렉터리(`<모듈>-t.build`)로 셌다.
- 변경이 없어도 매번 컴파일되는 명령 플러그인(`NewRib`)과 매니페스트는 세지 않았다.

## 샘플 경계 검사

`Samples/TodoModular`의 피처 경계(ADR-0024)와 샘플의 순수 뷰 규칙(ADR-0027)을 import 문으로 검사합니다(ADR-0028). 빌드가 필요 없어 어느 호스트에서나 돕니다.

```sh
scripts/check-sample-boundaries.sh   # 위반이 있으면 파일과 import를 출력하고 실패
```

macOS에서는 SwiftPM의 검사도 함께 쓸 수 있습니다. 선언하지 않은 모듈을 import하면 빌드가 실패합니다.

```sh
swift build --package-path Samples/TodoModular/Shared --explicit-target-dependency-import-check error
```

이 옵션은 Windows 호스트와 Wasm SDK 빌드(`--swift-sdk ..._wasm`)에서는 위반을 잡지 못합니다. `--build-system native`와 `--target`을 붙여도 잡지 못합니다.

## Windows

swift.org 툴체인 6.4.2(`winget install Swift.Toolchain --version 6.4.2`), Visual Studio Build Tools 2022(C++ 도구, Windows SDK)가 필요합니다. 의존성 체크아웃에 심볼릭 링크가 있어 **개발자 모드**를 켜야 합니다. 명령은 `vcvars64.bat`를 부른 셸에서 실행하고, 설치 직후 새 환경 변수를 못 받은 셸이면 `SDKROOT`를 직접 잡습니다.

```bat
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
set SDKROOT=%LOCALAPPDATA%\Programs\Swift\Platforms\6.4.2\Windows.platform\Developer\SDKs\Windows.sdk\
swift build && swift test
```

Windows 호스트에서 Android 샘플을 빌드하는 방법은 [Android 샘플 README](../Samples/AndroidLogin/README.md#windows에서-빌드)에 있습니다.

### 웹 샘플은 Windows 호스트에서 빌드되지 않는다

`Samples/WebLogin`과 `Samples/TodoModular/Web`은 Windows 호스트에서 빌드할 수 없습니다. macOS나 Linux에서 빌드합니다.

- 원인은 JavaScriptKit 0.63.0의 `PackageToJS` 플러그인입니다. `stderr`를 Darwin·Glibc·Musl·Android에서만 import해서 Windows에서 컴파일되지 않습니다.

  ```
  .build/checkouts/JavaScriptKit/Plugins/PackageToJS/Sources/PackageToJSPlugin.swift:584:27: error: cannot find 'stderr' in scope
  ```

- 패키지 플러그인은 빌드 전에 컴파일되므로 `swift package ... js`뿐 아니라 `swift build --swift-sdk ..._wasm`도 같은 자리에서 실패합니다.
- 2026-11-25 기준 0.63.0이 최신 릴리스이고, 업스트림 `main`에도 같은 코드가 있습니다. 업스트림 이슈는 [swiftwasm/JavaScriptKit#818](https://github.com/swiftwasm/JavaScriptKit/issues/818)입니다(열림).
- Windows PC에서는 WSL로 빌드합니다([아래](#wsl에서-빌드)).

### swift-java를 쓰는 Android 샘플은 Windows 호스트에서 빌드되지 않는다

`Samples/TodoModular/Android`와 `Samples/AndroidLogin`은 swift-java 0.7.0을 씁니다(ADR-0021). Windows 호스트에서는 호스트 빌드와 Android 교차 빌드가 모두 swift-java 플러그인 단계에서 실패합니다. macOS나 Linux에서 빌드합니다.

- 원인은 swift-java 플러그인이 경로를 `URL.path(percentEncoded: false)`로 넘기는 데 있습니다. Windows에서는 이 값이 `/C:/Users/...` 모양이라 실행 파일과 출력 파일을 찾지 못합니다. 업스트림 이슈는 [swiftlang/swift-java#920](https://github.com/swiftlang/swift-java/issues/920)입니다(2026-11-25 기준 열림, 0.7.0이 최신 릴리스).
- 호스트 빌드(`Samples/TodoModular/Android/swift`에서 `swift build`): Kotlin이 구현하는 Swift 프로토콜(`enableJavaCallbacks`)을 처리하는 `JExtractSwiftPlugin`이 Gradle 래퍼를 실행하지 못합니다(`Plugins/JExtractSwiftPlugin/JExtractSwiftPlugin.swift:216-221`).

  ```
  Error: Executable "\C:\...\Samples\TodoModular\Android\swift\.build\checkouts\swift-java\gradlew" is not found or cannot be executed.
  error: CustomTask Build\ SwiftKitCore,\ compile\ Java\ callbacks,\ and\ generate\ Swift\ wrappers ... failed with a nonzero exit code.
  ```

- 앱 빌드(`Samples/TodoModular/Android`에서 `gradlew.bat :app:assembleDebug -PswiftAbis=x86_64`, vcvars64 셸): `:bridge:swiftBuildX86_64`가 18분쯤 의존성을 빌드한 뒤 `_StaticBuildConfigPlugin`에서 실패합니다. 출력 파일 인자가 `/C:/.../static-build-config.json`입니다.

  ```
  error: CustomTask Run\ -print-static-build-config ... failed with a nonzero exit code.
  > Task :bridge:swiftBuildX86_64 FAILED
  ```

- 위의 Windows 행에 있던 "Android `.so` 교차 빌드, APK 빌드, 에뮬레이터 계측 테스트 통과"는 2026-11-14 기록입니다. AndroidLogin이 swift-java로 바뀌기(2026-11-20) 전이라 지금 코드에는 해당하지 않아 지웠습니다. AndroidLogin을 지금 코드로 다시 빌드해 보지는 않았습니다. 같은 플러그인을 거치므로 같은 자리에서 실패할 것으로 봅니다.
- 의존성을 고쳐 쓰는 방법(패치, fork)은 쓰지 않습니다. Windows PC에서는 WSL로 빌드합니다([아래](#wsl에서-빌드)).

### WSL에서 빌드

Windows PC에서 웹 샘플과 swift-java를 쓰는 Android Swift 패키지는 WSL Ubuntu에서 빌드합니다. 2026-11-25에 Ubuntu 24.04(WSL 2, x86_64)에서 확인했습니다.

| 대상 | 결과 |
|---|---|
| 루트 `swift test` | 145개 통과. `NewRibTests`(생성한 뼈대·연결 코드 빌드) 6개 포함 |
| `Samples/TodoModular/Android/swift`의 `swift test --disable-sandbox` | 13개 통과 |
| `Samples/TodoModular/Web`: `swift package ... js` → `npm ci` → `npm run build` → `npm run test:e2e` | e2e 24개 통과 |
| `Samples/WebLogin` e2e | 5개 통과 |

설치한 것:

- `wsl --install -d Ubuntu-24.04`
- swift.org 6.4.2 Linux 툴체인(`swift-6.4.2-RELEASE-ubuntu24.04.tar.gz`)과 swift.org가 안내하는 apt 의존성
- Swift SDK `swift-6.4.2-RELEASE_wasm`: download.swift.org에서 받은 `swift-6.4.2-RELEASE_wasm.artifactbundle.tar.gz`를 로컬 파일로 `swift sdk install`. 받은 파일의 SHA-256은 `83baca83553f8c443cda7b84800912e6e709c3acd2e7ebf277794ca5836c0da5`였습니다. 이 값은 받은 파일에서 계산한 것이고 swift.org가 공개한 값과 대조하지 않았습니다.
- Node.js 22(nodejs.org Linux x64 tar), OpenJDK 21(`openjdk-21-jdk-headless`, `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64`)

주의할 점:

- 레포는 WSL 파일 시스템(`~/...`)에 clone합니다. Windows 쪽 레포를 `git clone /mnt/c/...`로 받으면 로컬 브랜치도 함께 옵니다. `/mnt/c` 아래에서 직접 빌드하는 경로는 확인하지 않았습니다.
- e2e는 root가 아닌 사용자로 돌립니다. root로 돌리면 Puppeteer의 Chrome이 `Running as root without --no-sandbox is not supported`로 뜨지 않고, 테스트가 실패한 채 끝나지 않습니다.
- Android 앱(APK) 빌드와 에뮬레이터 계측 테스트는 WSL에서 확인하지 않았습니다.

### Tauri(WebView2)에서 웹 샘플

WSL에서 빌드한 `Samples/TodoModular/Web/dist/`를 레포 밖 임시 Tauri 앱(`tauri-cli` 2.12.6, `frontendDist`만 지정)에 넣고 Windows 11의 WebView2 158에서 열어 확인했습니다(2026-11-25). Tauri 프로젝트는 레포에 넣지 않았습니다.

- 출처는 `http://tauri.localhost`입니다.
- Wasm은 `application/wasm`으로 오고, 전체 앱에서 로그인 뒤 할 일 목록 3개가 뜹니다.
- 정적 JSON `/api/todos`는 확장자가 없어 `text/html`로 옵니다. 앱은 본문을 JSON으로 읽어서 동작에는 문제가 없습니다.
- 쓰기 요청 스파이크(`spikes/write-request.html`)로 다른 출처(`http://localhost:<포트>`)의 API를 불렀습니다.
  - POST: 프리플라이트(`OPTIONS`) 뒤 `Authorization: Bearer`와 JSON 본문(한글 포함)이 그대로 가고, 201 응답을 `created`로 읽습니다.
  - 409는 Problem Details `title`과 함께 `conflict`로, 본문이 있는 PATCH도 그대로 갑니다.
  - 서버가 CORS를 허용하지 않으면 `unreachable`이 됩니다(ADR-0034).
- 관찰: 같은 주소로 프리플라이트가 성공한 지 5초 안이면 WebView2가 프리플라이트를 다시 보내지 않습니다(Chromium 기본 캐시). 이때 서버가 실제 응답에서 CORS 헤더를 빼면 POST는 서버에 도착해 처리되고, 앱은 응답을 읽지 못해 `unreachable`만 압니다. 5초가 지난 뒤에는 `OPTIONS`만 가고 POST는 나가지 않았습니다. `unreachable`인 쓰기 요청을 다시 보내면 서버에서 두 번 처리될 수 있습니다. 분류(ADR-0034)는 바꾸지 않았습니다.

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
