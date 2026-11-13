### ADR-0001 uber/RIBs-iOS를 원본으로 삼는다
- 상태: 채택
- 날짜: 2026-11-13
- 배경: carti-RIBs-KMP는 ADR-0010에서 RIBs-iOS를 원본으로 바꿨다. Swift 포트도 같은 기준을 써야 두 구현의 API와 생명주기 순서가 어긋나지 않는다.
- 결정: `uber/RIBs-iOS`의 `RIBs/Classes`를 원본으로 삼는다. 타입·메서드 이름(`activate`/`deactivate`, `didBecomeActive`/`willResignActive`, `Router.load`/`didLoad`, `attachChild`/`detachChild`, `LaunchRouter.launch(from:)`)과 순서(attach 시 활성화 후 로드, launch 시 뷰 표시 → 활성화 → 로드)를 따른다. KMP에 있는 확장(상태 복원, `handleBackPress`, `mount`/`unmount`, `shutdown`)도 옮긴다.
- 고려했던 대안:
  (1) RIBs-iOS를 그대로 포크: Rx·UIKit·Foundation 의존이 깊어 Linux·Wasm에서 빌드되지 않아 기각했다.
  (2) KMP 코드를 Swift로 직역: Kotlin 관용(`StateFlow`, `CoroutineScope`)이 Swift에 맞지 않고 iOS 개발자에게 낯설어 기각했다.
- 결과: iOS 템플릿과 같은 모양의 RIB을 쓴다. 누수 감지(`LeakDetector`)와 `ComponentizedBuilder`의 같은 Component 재사용 검사는 옮기지 않는다.
- 관련: ADR-0002, carti-RIBs-KMP ADR-0010
