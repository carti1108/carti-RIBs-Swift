# 빌드와 검증

## 플랫폼별 상태

| 플랫폼 | 상태 |
|---|---|
| macOS·iOS | 로컬 빌드·테스트, iOS 샘플 UI 테스트 |
| Linux | Static Linux SDK(musl, x86_64·aarch64)로 `RIBs`·`LoginShared`·`RIBsWeb` 교차 빌드 확인. Linux 호스트가 없어 테스트는 실행하지 않음 |
| Wasm·Android | 6.4.2 Swift SDK 빌드, 웹 E2E·Android 샘플 APK 빌드 |
| Windows | 6.4.2 툴체인으로 루트 `swift build`·`swift test`(132개), `Samples/TodoModular/Shared`의 `swift build`·`swift test`(72개) 통과(2026-11-25). 웹 샘플은 빌드 불가([아래](#웹-샘플은-windows-호스트에서-빌드되지-않는다)). swift-java를 쓰는 Android 샘플도 빌드 불가([아래](#swift-java를-쓰는-android-샘플은-windows-호스트에서-빌드되지-않는다)) |

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
- µFeature 샘플(`Samples/TodoModular`, ADR-0024): [Web](../Samples/TodoModular/Web/README.md)

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
- WSL(Ubuntu)에 Linux 툴체인을 설치해 빌드하는 경로는 확인하지 않았습니다.

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
- 의존성을 고쳐 쓰는 방법(패치, fork)은 쓰지 않습니다.

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
