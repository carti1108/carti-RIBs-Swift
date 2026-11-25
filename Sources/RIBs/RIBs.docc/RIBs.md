# ``RIBs``

Foundation 없이 Swift Concurrency로 옮긴 크로스플랫폼 RIBs(Router-Interactor-Builder) 코어.

## 개요

[uber/RIBs-iOS](https://github.com/uber/RIBs-iOS)의 이름·시그니처·호출 순서를 따르되, Rx 대신 Swift Concurrency를 쓰고 표준 라이브러리만 의존합니다. 생명주기 타입은 모두 `@MainActor`라서 같은 코어가 macOS·iOS·Linux·Wasm·Android에서 그대로 빌드됩니다.

RIB 하나는 다음으로 이루어집니다.

- ``Builder``: ``Component``로 의존성을 모아 Router·Interactor·뷰를 만든다.
- ``Interactor``: 비즈니스 로직. 활성 구간 동안만 일한다.
- ``Router``: 자식 RIB을 붙이고 떼어 트리를 만든다. 화면이 있으면 ``ViewableRouter``.
- ``Presenter``/뷰: ``ViewControllable``을 따르는 불투명한 화면 객체. 실제 UI는 플랫폼 어댑터가 그린다.

## 생명주기

``Interactor``는 Router가 트리에 붙을 때 ``Interactor/activate()``되고 떨어질 때 ``Interactor/deactivate()``됩니다. 하위 클래스는 ``Interactor/didBecomeActive()``와 ``Interactor/willResignActive()``를 재정의합니다. 상태는 ``Interactor/isActive``, ``Interactor/isActiveStream``, ``Interactor/observeActive(_:)``로 볼 수 있습니다.

비동기 작업은 ``Interactor/task(_:)``로 띄웁니다. 비활성화되면 Task가 취소되므로 `Task {}`를 직접 들고 있을 필요가 없습니다. 활성 전에 부르면 ``LifecycleError/notStarted(owner:)``, 비활성 뒤에 부르면 ``LifecycleError/ended(owner:)``를 던집니다. 외부 `AsyncStream`은 `AsyncStream.confineTo(_:)`로 활성 구간에 묶습니다.

```swift
final class TimerInteractor: Interactor {
    override func didBecomeActive() {
        try? task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                // 매초 갱신
            }
        }
    }
}
```

## 라우팅

부모 Router는 ``Router/attachChild(_:)``로 자식을 붙이고 ``Router/detachChild(_:)``로 뗍니다. 붙는 순간 자식의 ``Router/load()``와 Interactor 활성화가 일어나고, 떼면 하위 트리 전체가 비활성화됩니다. 상태를 저장·복원할 자식은 ``Router/attachChild(_:tag:)``로 태그를 줍니다.

트리의 뿌리는 ``LaunchRouter``입니다. ``LaunchRouter/launch(from:savedInstanceState:)``가 루트 화면을 ``ViewHost``에 붙이고, ``LaunchRouter/shutdown()``이 트리를 내립니다. 화면 없는 하위 트리는 ``Router/mount(savedInstanceState:)``로 붙이고 ``RibMount/unmount()``로 내립니다.

뒤로 가기는 ``Router/handleBackPress()``가 받아 기본적으로 ``Interactor/handleBackPress()``에 묻습니다. 원본 iOS에는 없는 확장입니다.

## Worker

``Worker``는 Interactor 활성 구간에 묶이는 백그라운드 작업 단위입니다. ``Worker/start(_:)``에 ``InteractorScope``를 넘기면 그 Interactor가 비활성화될 때 함께 멈춥니다. 하위 클래스는 ``Worker/didStart(_:)``·``Worker/didStop()``을 재정의하고, 작업은 ``Worker/task(_:)``로 띄웁니다.

## 상태 저장과 복원

원본 iOS에는 없고 KMP 구현과 맞춘 확장입니다.

1. ``Interactor/onSaveInstanceState(_:)``에서 저장할 값을 ``RibValue``로 채운다.
2. ``Router/saveInstanceState()``가 하위 트리 전체를 ``RibState``로 모은다. 태그 있는 자식만 저장된다.
3. ``RibState/encodedString()``으로 문자열로 만들어 플랫폼 저장소(iOS `SceneStorage`, 웹 `sessionStorage`, Android `Bundle`)에 둔다.
4. 다음 실행에서 ``RibState/init(decoding:)``으로 읽고 ``LaunchRouter/launch(from:savedInstanceState:)``에 넘긴다. 각 Interactor는 ``Interactor/savedInstanceState``로 자기 값을 읽는다.

문자열이 깨졌으면 ``RibStateDecodingError``를 던집니다.

## 플랫폼 어댑터

코어는 UI 프레임워크를 모릅니다. 뷰 계약과 ``ViewHost``를 구현한 별도 라이브러리가 화면을 붙입니다.

| 라이브러리 | 플랫폼 | 하는 일 |
|---|---|---|
| `RIBsSwiftUI` | Apple | `SwiftUIRenderable`, `RIBScreenSlot`, `RIBScreenStack`, `SwiftUIViewHost` |
| `RIBsUIKit` | iOS·tvOS·visionOS | `UIKitViewControllable`, `RIBContainerViewController`, `WindowViewHost` |
| `RIBsWeb` | Wasm(브라우저) | `WebScreenSlot`. DOM은 앱이 JavaScriptKit으로 그린다 |
| `RIBsAndroid` | Android | `AndroidScreen`, `AndroidRenderer`, `AndroidMainLooper`(메인 큐를 메인 Looper에 붙임) |

## Topics

### 빌더와 의존성

- ``Builder``
- ``ComponentizedBuilder``
- ``SimpleComponentizedBuilder``
- ``Buildable``
- ``Component``
- ``EmptyComponent``
- ``Dependency``
- ``EmptyDependency``

### Interactor

- ``Interactor``
- ``PresentableInteractor``
- ``Interactable``
- ``InteractorScope``
- ``ActiveObservation``
- ``LifecycleError``

### Router

- ``Router``
- ``ViewableRouter``
- ``LaunchRouter``
- ``Routing``
- ``ViewableRouting``
- ``LaunchRouting``
- ``RouterScope``
- ``RouterLifecycle``
- ``RibMount``

### 화면

- ``Presenter``
- ``Presentable``
- ``ViewControllable``
- ``ViewHost``

### Worker

- ``Worker``
- ``Working``

### 상태 저장

- ``RibState``
- ``RibValue``
- ``RibStateDecodingError``
