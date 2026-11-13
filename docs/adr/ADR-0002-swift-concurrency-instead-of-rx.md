### ADR-0002 Rx 대신 Swift Concurrency를 쓴다
- 상태: 채택
- 날짜: 2026-11-13
- 배경: RIBs-iOS는 RxSwift로 활성 상태를 퍼뜨리고 `disposeOnDeactivate`로 구독을 정리한다. RxSwift·Combine은 외부 의존이거나 Apple 전용이다.
- 결정: 표준 `_Concurrency`만 쓴다. `isActiveStream`·`lifecycle`·`isStartedStream`은 `AsyncStream`, `disposeOnDeactivate`/`disposeOnStop`은 `Interactor.task(_:)`/`Worker.task(_:)`로 띄운 Task를 구간 종료 때 취소하는 방식으로 바꾼다. 활성 구간 밖에서 `task`를 부르면 `LifecycleError`(`notStarted`/`ended`)를 던진다. Worker의 Interactor 구독은 결정적 순서를 위해 동기 콜백(`observeActive`)으로 한다.
- 고려했던 대안:
  (1) RxSwift: 원본과 같지만 외부 의존이고 Swift 6 엄격 동시성과 맞지 않아 기각했다.
  (2) Combine: Linux·Wasm에 없어 기각했다.
  (3) 구독도 전부 `AsyncStream`: 전달이 비동기라 Worker 시작·정지 순서가 테스트에서 비결정적이 되어 기각했다.
- 결과: 외부 의존이 없다. `confineTo(_:)`는 `AsyncStream` 확장으로 두되, 원본(combineLatest)과 달리 비활성 중 도착한 마지막 값을 재활성 때 다시 보내지 않는다.
- 관련: ADR-0003, ADR-0004
