# carti-RIBs-Swift

[uber/RIBs-iOS](https://github.com/uber/RIBs-iOS)를 순수 Swift로 옮긴 크로스플랫폼 RIBs 코어입니다.

RIBs-iOS에 없는 확장이 두 가지 있습니다. 루트를 붙였다 떼는 `Router.mount`/`RibMount`, 트리 상태를 저장·복원하는 `RibState`입니다. RIBs-Android에서 가져왔고, 쓰지 않으면 RIBs-iOS와 같게 동작합니다(ADR-0016).

- Swift 6 언어 모드, 엄격한 동시성, 생명주기 타입은 `@MainActor`
- Swift Concurrency만 사용(Rx·Combine 없음). 비동기 작업은 `Interactor.task(_:)`로 활성 구간에 묶음
- 코어 타깃 `RIBs`는 Foundation 없이 표준 라이브러리만 사용
- 수동 DI(`Component<Dependency>`), 불투명한 `ViewControllable`

## 요구 사항

| 대상 | 툴체인 |
|---|---|
| macOS·iOS, Linux | Swift 6.2 이상 |
| Wasm, Android | swift.org 툴체인 6.4.2와 해당 Swift SDK(`swift-6.4.2-RELEASE_wasm`, `swift-6.4.2-RELEASE_android`) |
| Windows | swift.org 툴체인 6.4.2, Visual Studio Build Tools 2022 |

플랫폼별 검증 범위와 Windows·Linux 빌드 방법은 [빌드 문서](docs/building.md)에 있습니다.

## 사용

```swift
.package(url: "https://github.com/carti1108/carti-RIBs-Swift.git", branch: "main")
// target dependencies: ["RIBs"]
```

## 빌드

```sh
swift build
swift test
scripts/check-api.sh   # 공개 API 덤프 비교(macOS)
```

## 샘플

같은 `LoginShared` RIB 트리(로그인 → 할 일 목록 → 상세)를 세 플랫폼에서 그립니다.

| 플랫폼 | 위치 | 어댑터 |
|---|---|---|
| iOS (SwiftUI) | [Samples/iOSLogin](Samples/iOSLogin/README.md) | `RIBsSwiftUI` |
| 웹 (Wasm) | [Samples/WebLogin](Samples/WebLogin/README.md) | `RIBsWeb` |
| Android (Compose) | [Samples/AndroidLogin](Samples/AndroidLogin/README.md) | `RIBsAndroid` |

실행 방법과 구조는 각 샘플의 README에 있습니다.

## 새 RIB 만들기

```sh
# 한 모듈 안에 RIB 하나
swift package --allow-writing-to-package-directory new-rib \
  --name Profile --sources Sources/App --tests Tests/AppTests --module App [--swiftui Sources/AppUI]

# µFeature 피처 하나(Interface·Impl·Testing·Tests 디렉터리)
swift package --allow-writing-to-package-directory new-rib \
  --feature Profile [--root Features] [--prefix Feature] [--swiftui iOS/Features/Profile]

# 플랫폼 연결 코드만(Android·Web 패키지에서 실행)
swift package --allow-writing-to-package-directory new-rib \
  --connect Profile --web Sources --web-bridge TodoModularWeb --web-support TodoWebSupport
```

- 뷰 계약은 `render(_ state:)`와 `handle(_ action:)` 모양으로 만듭니다(`XxxViewState`, `XxxViewAction`). 라이브러리가 이 모양을 요구하지는 않습니다.
- `--swiftui`를 주면 순수 뷰(`XxxView`, SwiftUI만 import)와 어댑터(`XxxScreen`)를 따로 만듭니다. 피처 모드에서는 `UI/`와 `Adapter/` 아래에 둡니다.
- `--android <소스 디렉터리> --android-bridge <타깃> --android-support <모듈>`은 Swift 화면(`XxxAndroidScreen`)과 swift-java 핸들(`XxxScreenHandle`, `XxxViewBridge`)을 만듭니다. `--web` 세 옵션은 Swift 화면(`XxxWebScreen`)과 BridgeJS 브리지(`XxxBridge.swift`)를 만듭니다. `--feature`에 함께 주거나, 공유 코드와 플랫폼 코드가 다른 패키지면 `--connect`로 따로 만듭니다.
  - TodoModular 샘플의 구조를 전제로 합니다. support 모듈에 `BridgedScreen`·`WebScreen`이, Android 브리지 타깃에 전역 `controller`가 있어야 합니다.
  - 처음 한 번 만드는 뼈대입니다. `XxxViewState`·`XxxViewAction`을 바꾸면 브리지의 인자와 핸들 메서드는 손으로 맞춥니다. Kotlin·JS 쪽 뷰는 만들지 않습니다.
- 피처 모드는 `Package.swift`를 고치지 않고 넣을 줄을 출력합니다.
- 이미 있는 파일은 덮어쓰지 않습니다.

## 문서

- [빌드와 검증](docs/building.md)
- [원본 대비 비교](docs/upstream-comparison.md)
- [ADR 목록](docs/adr/README.md)
- [작업 규칙](AGENTS.md)

## 라이선스

[uber/RIBs-iOS](https://github.com/uber/RIBs-iOS)(Copyright (c) 2017 Uber Technologies)의 설계와 API를 바탕으로 다시 구현한 파생 프로젝트이며, Apache License 2.0으로 배포합니다. 전문은 [LICENSE.txt](LICENSE.txt)를 참고하세요. Uber의 공식 프로젝트가 아닙니다.
