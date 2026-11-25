### ADR-0019 코어는 뷰 계약의 모양을 강제하지 않는다
- 상태: 채택 (샘플 통일 여부는 ADR-0025로 대체됨)
- 날짜: 2026-11-20
- 배경:
  - 로그인 샘플의 LoggedOut RIB은 뷰 계약을 `render(_ state: LoggedOutViewState)`와 `handle(_ action: LoggedOutViewAction)` 두 메서드로 바꿨다(커밋 `bb6ab17`). 상태 변경이 렌더 한 번으로 묶이고, 실패 응답에서 오류와 로딩이 따로 그려지는 문제가 없어졌다.
  - 나머지 네 RIB(Root, LoggedIn, TodoList, TodoDetail)은 `showUserName(_:)`, `showTodos(_:)` 같은 명령형 메서드를 그대로 쓴다. 원본 RIBs-iOS도 `Presentable`과 `PresentableListener`의 메서드 모양을 정하지 않는다(ADR-0001).
  - 이 패턴을 코어(`Sources/RIBs`)의 프로토콜이나 기반 클래스로 올릴지 정해야 한다.
- 결정:
  - `Sources/RIBs`에는 `ViewState`·`ViewAction`에 해당하는 프로토콜, 연관 타입, 기반 클래스를 두지 않는다. `Presentable`은 지금처럼 표식 프로토콜로 남긴다.
  - 뷰 계약의 메서드 모양은 RIB마다 앱이 정한다. `render(state)` 한 개여도 되고 명령형 메서드 여러 개여도 된다.
  - `ViewState`/`ViewAction`은 샘플의 사용 예시로만 둔다. 지금은 LoggedOut RIB 하나다.
- 고려했던 대안:
  (1) 코어에 `protocol StatefulPresentable { associatedtype ViewState; func render(_:) }`를 두고 권장: 연관 타입이 생기면 `any LoggedOutPresentable` 같은 존재 타입 사용이 번거로워지고, 원본에 없는 API가 코어에 늘어난다(ADR-0001). 화면 하나로 검증한 패턴을 코어에 고정하기에는 근거가 부족해 기각했다.
  (2) 모든 샘플 RIB을 `ViewState`/`ViewAction`으로 통일: 자식 화면을 담는 RIB(Root, LoggedIn)은 `showScreen`/`hideScreen`이 상태 값으로 표현되지 않는다. 통일하려면 화면 슬롯까지 상태에 넣어야 해서 기각했다.
  (3) LoggedOut도 명령형으로 되돌리기: 한 번의 변경이 렌더 여러 번으로 나뉘는 문제가 돌아와 기각했다.
- 결과:
  - 플랫폼 경계(ADR-0020)는 화면마다 메서드 모양이 다를 수 있다는 전제에서 설계한다.
  - 샘플 안에 두 가지 스타일이 섞여 있다. 어느 쪽을 쓸지는 문서에서 "앱이 고른다"고 안내해야 한다.
- 관련: ADR-0001, ADR-0006, ADR-0008, ADR-0020
