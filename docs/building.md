# 빌드와 검증

## 플랫폼별 상태

| 플랫폼 | 상태 |
|---|---|
| macOS·iOS | 로컬 빌드·테스트, iOS 샘플 UI 테스트 |
| Linux | Static Linux SDK(musl, x86_64·aarch64)로 `RIBs`·`LoginShared`·`RIBsWeb` 교차 빌드 확인. Linux 호스트가 없어 테스트는 실행하지 않음 |
| Wasm·Android | 6.4.2 Swift SDK 빌드, 웹 E2E·Android 샘플 APK 빌드 |
| Windows | 6.4.2 툴체인으로 `swift build`·`swift test` 통과. Windows 호스트에서 Android `.so` 교차 빌드, x86_64 APK 빌드, 에뮬레이터 계측 테스트 통과 |

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


swift.org 툴체인 6.4.2(`winget install Swift.Toolchain --version 6.4.2`), Visual Studio Build Tools 2022(C++ 도구, Windows SDK)가 필요합니다. 의존성 체크아웃에 심볼릭 링크가 있어 **개발자 모드**를 켜야 합니다. 명령은 `vcvars64.bat`를 부른 셸에서 실행하고, 설치 직후 새 환경 변수를 못 받은 셸이면 `SDKROOT`를 직접 잡습니다.

```bat
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
set SDKROOT=%LOCALAPPDATA%\Programs\Swift\Platforms\6.4.2\Windows.platform\Developer\SDKs\Windows.sdk\
swift build && swift test
```

Windows 호스트에서 Android 샘플을 빌드하는 방법은 [Android 샘플 README](../Samples/AndroidLogin/README.md#windows에서-빌드)에 있습니다.

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
