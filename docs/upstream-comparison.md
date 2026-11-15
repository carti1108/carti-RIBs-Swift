# 원본(uber/RIBs-iOS) 대비 파일 비교

기준: [uber/RIBs-iOS](https://github.com/uber/RIBs-iOS) `main` 브랜치, `RIBs/Classes/` (2026-11-14 확인). [ADR-0001](adr/ADR-0001-uber-ribs-ios-as-reference.md).
우리 쪽: `Sources/RIBs/`.

표기: ✅ 같음(이름·순서 유지, Rx→Swift Concurrency 치환만) · 🔶 형태 변경 · ⛔ 의도적 제외 · ➕ 원본에 없는 확장

## RIBs/Classes

| 원본 파일 | 상태 | 우리 파일 | 비고 |
|---|---|---|---|
| `Interactor.swift` (`InteractorScope`, `Interactable`, `Interactor`) | ✅ | `Interactor.swift` | `activate`/`deactivate`/`didBecomeActive`/`willResignActive`. `isActiveStream`은 `AsyncStream<Bool>` |
| `Interactor.swift` `confineTo(_:)` | ✅ | `Interactor.swift` | `AsyncStream`에 대한 확장 |
| `Interactor.swift` `disposeOnDeactivate` | 🔶 | `Interactor.task(_:)`, `TaskScope.swift` | 활성 구간에 묶인 `Task`, 비활성화 때 취소(ADR-0002) |
| `PresentableInteractor.swift` | ✅ | `Interactor.swift` | 누수 감지 없음 |
| `Presenter.swift` | ✅ | `Presenter.swift` | |
| `Router.swift` | ✅ | `Router.swift` | `load`/`didLoad`, `attachChild`/`detachChild`, attach 시 활성화 후 로드. `lifecycle`은 `AsyncStream` |
| `ViewableRouter.swift` | ✅ | `ViewableRouter.swift` | |
| `LaunchRouter.swift` | 🔶 | `LaunchRouter.swift` | `UIWindow` 대신 불투명한 `ViewHost`로 띄운다(ADR-0006). `shutdown()` 추가 |
| `ViewControllable.swift` | 🔶 | `ViewControllable.swift` | UIKit 없는 불투명 프로토콜과 `ViewHost`(ADR-0006, ADR-0007) |
| `Builder.swift` | ✅ | `Builder.swift` | |
| `ComponentizedBuilder.swift` | 🔶 | `Builder.swift` | 같은 Component 재사용 검사 제외(ADR-0001) |
| `MultiStageComponentizedBuilder.swift` | ⛔ | — | 옮기지 않음 |
| `DI/Component.swift` | 🔶 | `Component.swift` | `shared(_:)`는 키 문자열로 캐시. Foundation 없음(ADR-0004, ADR-0005) |
| `DI/Dependency.swift` | ✅ | `Component.swift` | `Dependency`, `EmptyDependency` |
| `Worker/Worker.swift` | 🔶 | `Worker.swift` | `start`/`stop`/`didStart`/`didStop` 유지, Rx 대신 `Worker.task(_:)`(ADR-0002) |
| `Workflow/Workflow.swift` | ⛔ | — | Rx 기반이라 옮기지 않음(ADR-0002) |
| `Concurrency/Observable+Async.swift` | ⛔ | — | Rx 연결용이라 해당 없음(ADR-0002) |
| `Concurrency/Task+RIBs.swift` | 🔶 | `TaskScope.swift`, `Interactor.task(_:)` | |
| `Extensions/Foundation+Extensions.swift` | ⛔ | — | 코어는 Foundation을 쓰지 않음(ADR-0004) |
| `LeakDetector/Executor.swift`, `LeakDetector/LeakDetector.swift` | ⛔ | — | 누수 감지 제외(ADR-0001) |

## 원본에 없는 것

| 우리 파일 | 내용 |
|---|---|
| `RibState.swift`, `RibStateCodec.swift` | 트리 상태 저장·복원(`onSaveInstanceState`, `saveInstanceState`). RIBs-Android·KMP에서 가져옴(ADR-0016) |
| `RibMount.swift` | `Router.mount`/`RibMount`로 루트를 붙였다 떼기(ADR-0016) |
| `ActiveState.swift` | `observeActive(_:)`가 돌려주는 `ActiveObservation` |
| `LifecycleError.swift` | 복구 가능한 생명주기 실패(typed throws) |
| `Interactor.handleBackPress()`, `Router.handleBackPress()` | 뒤로가기 전달. KMP에서 가져옴(ADR-0001) |
