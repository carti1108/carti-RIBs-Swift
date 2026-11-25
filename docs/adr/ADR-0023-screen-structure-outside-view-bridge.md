### ADR-0023 화면 구조는 브리지 밖에 두고, 목록 항목은 경계용 값 타입으로 넘긴다
- 상태: 채택
- 날짜: 2026-11-20
- 배경:
  - ADR-0020은 LoggedOut 화면 하나만 브리지로 옮기고, 자식 화면을 담는 RIB(Root, LoggedIn)을 어떻게 옮길지는 미뤘다. 나머지 네 화면을 옮기면서 세 가지를 정해야 했다.
  - 자식 화면 자리: 뷰 계약의 `showScreen(_:)`/`hideScreen(_:)`은 `any ViewControllable`을 받는다. swift-java 0.7.0은 `any 프로토콜` 반환에서 잘못된 코드를 만들고, BridgeJS는 프로토콜 요구 사항의 프로토콜 타입 인자·반환을 지원하지 않는다. 화면 객체를 브리지 메서드로 넘길 수 없다.
  - 목록: TodoList는 `[Todo]`를 그린다. `Todo`는 루트 패키지의 `LoginShared`에 있어 도구가 내보내지 못한다. ADR-0020의 "인자는 기본 타입으로 둔다", "`LoginShared`의 타입을 브리지 쪽에 복제하지 않는다"로는 목록 한 줄을 표현할 수 없다.
  - Android에서 목록을 콜백 인자로 넘기면 앱이 멈춘다. swift-java 0.7.0은 직접 만든 타입의 배열을 Java로 넘길 때 JNI `FindClass`로 원소 클래스를 찾는다. Swift `Task`에서 시작한 호출(예: `TodoListInteractor.didBecomeActive`의 비동기 갱신)에는 Java 호출 스택이 없어 부트 클래스 로더가 쓰이고, `NoClassDefFoundError`가 걸린 채 `NewObjectArray`가 불려 ART가 프로세스를 중단한다. 계측 테스트 `configurationChangeKeepsTodoDetailAndTree`에서 재현했다. Kotlin이 부른 호출 안에서 넘길 때(`attach` 직후의 첫 렌더)는 문제가 없다.
- 결정:
  - 화면 구조(어느 화면이 어느 화면의 자식인가)는 브리지 프로토콜에 넣지 않는다. 플랫폼마다 이미 있는 통로를 쓴다.
    - Android: `RIBsAndroid`의 화면 트리(JSON)가 `kind`, `id`, `child`만 싣는다. Kotlin은 `kind`로 Composable을 고르고 `id`로 화면별 핸들을 만든다. 상태 키(`userName`, `todos` 등)와 문자열 입력 경로(`dispatch(screenID:action:argument:)`, `nativeDispatch`)는 샘플에서 없앤다.
    - Web: Swift가 화면 자리(빈 요소)와 자식 화면 자리(`content`)를 만들고 `RIBsWeb`의 `WebScreenSlot`으로 자식을 채운다. JS 뷰는 `mount(host:content:handle:)`에서 `content`를 원하는 위치에 넣기만 한다.
  - 상태도 입력도 없는 화면(Root)에는 브리지를 두지 않는다.
  - 목록 항목은 브리지 층에 경계용 값 타입을 둔다(`TodoListRow`: `id`, `title`, `isDone`). ADR-0020의 "복제하지 않는다"는 화면 상태 한 덩어리(`LoggedOutViewState` 등)에 적용하고, 컬렉션의 원소 타입은 예외로 한다.
  - Android에서 직접 만든 타입의 배열은 콜백 인자로 넘기지 않는다. 브리지 프로토콜은 `rowsChanged()`로 바뀌었다고만 알리고, Kotlin이 `TodoListScreenHandle.rows()`로 읽어 간다. 기본 타입과 `String`, `Optional` 인자는 콜백으로 넘겨도 된다(계측 테스트에서 `Task`에서 시작한 렌더가 통과했다).
  - Web의 TodoList는 `render(rows: [TodoListRow])`로 넘긴다. id는 `Int`다. Wasm의 `Int`는 32비트라 범위를 넘는 id는 변환할 때 멈춘다.
  - `AndroidLoginUI`에 `BridgedScreen<State>`를 둬서 화면마다 반복되는 `attach`/`detach`/현재 상태 보관을 한곳에 둔다. 화면 조회는 `AndroidLoginController.screen(id:as:)` 하나로 한다.
- 고려했던 대안:
  (1) 구조도 브리지로 넘기기(`showChild(kind:id:)` 같은 메서드): 화면 종류를 문자열이나 열거형으로 다시 정의해야 하고, 지금 있는 화면 트리·`WebScreenSlot`과 같은 일을 하는 통로가 하나 더 생긴다. 기각했다.
  (2) Android 화면 트리를 없애고 화면마다 자식 핸들을 반환: swift-java가 `any 프로토콜` 반환을 제대로 만들지 못하고, 화면 종류별 구체 타입을 반환하려면 부모가 자식 종류를 모두 알아야 한다. `RIBsAndroid`(루트 패키지)도 바꿔야 해서 기각했다.
  (3) 목록을 기본 타입 배열 여러 개로 넘기기(`ids`, `titles`, `doneFlags`): 값 타입 없이 되고 Android에서도 콜백으로 넘길 수 있지만, 배열 길이와 순서를 호출 쪽이 맞춰야 한다. 기각했다.
  (4) Android도 `render(rows:)` 콜백 유지: 배경의 중단 때문에 불가능하다. swift-java가 클래스 참조를 미리 잡아 두도록 바뀌면 다시 검토한다.
  (5) Web도 Android처럼 알리고 읽어 가기로 통일: BridgeJS에는 같은 문제가 없어 호출이 한 번 늘 뿐이다. 통일하지 않았다.
- 결과:
  - 다섯 화면이 모두 옮겨졌다. Android 호스트 테스트 13개, 계측 테스트 8개(API 37), Web E2E 5개가 통과한다.
  - Android 화면 트리에 문자열 키가 세 개(`kind`, `id`, `child`)와 화면 종류 이름 다섯 개가 남는다. 이름이 어긋나면 Kotlin의 `error("Unknown screen kind")`로 런타임에 드러난다.
  - Android TodoList만 다른 화면과 모양이 다르다(알림 뒤 읽기). Kotlin은 읽은 값을 복사한 뒤 arena를 바로 닫는다.
  - `RIBsAndroid`의 `AndroidScreen.handle(action:argument:)`와 `AndroidRenderer.dispatch`는 샘플이 더 이상 쓰지 않는다. 루트 패키지의 공개 API라 이 ADR에서는 지우지 않았다.
  - 릴리스 Wasm이 10.20MB에서 10.25MB로 늘었다(전환 전 기준 10.16MB). Swift DOM 헬퍼(`DOMBuilder.button`, `JSObject` 확장)는 쓰는 곳이 없어 지웠다.
  - Web은 화면 종류마다 JS 뷰 객체 하나가 그 종류의 화면 여러 개를 차례로 맡는다(ADR-0022). 네 종류 모두 같은 규칙이다.
  - ADR-0020의 "지금은 LoggedOut 화면 하나만 이 구조"라는 서술과 "통일할지는 다시 정한다"는 이 ADR로 갱신된다. 핸들을 만드는 쪽(Android는 Kotlin, Web은 Swift)은 통일하지 않고 그대로 둔다.
- 관련: ADR-0019, ADR-0020, ADR-0021, ADR-0022
