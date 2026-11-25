### ADR-0032 샘플의 데이터 계층은 공유 모듈 `TodoData`에 두고, 이 모듈에만 FoundationEssentials를 허용한다
- 상태: 채택 (Web의 `?todoFailures=`와 "실제 전송 구현은 없다"는 ADR-0033으로 대체됨)
- 날짜: 2026-11-25
- 배경:
  - 이 포트의 목적은 뷰를 뺀 나머지를 플랫폼 사이에 공유하는 것이다. 그 "나머지"에는 네트워크 응답 해석과 저장소가 들어가는데, `TodoModular`에는 지연만 주는 `DelayedAuthService`와 하드코딩한 `TodoStore.sampleTodos`뿐이었다. 데이터 계층을 공유하는 모양이 검증되지 않았다.
  - 공유 코드는 Foundation을 쓰지 않았다(ADR-0004). JSON을 읽으려면 디코더를 손으로 짜거나 Foundation을 받아야 한다. ADR-0017은 코어와 공유 모듈에 `FoundationEssentials`를 허용하자고 제안했지만 채택되지 않았다.
  - `FoundationEssentials`의 비용은 크기다. ADR-0017의 실측으로 Wasm 릴리스 빌드가 5.55MB에서 12.76MB(gzip 1.61MB → 3.66MB)가 된다. 소유자가 이 비용을 받아들였다(2026-11-25).
- 결정:
  - `Samples/TodoModular/Shared/Data`에 `TodoData` 모듈을 둔다. 이 모듈만 `FoundationEssentials`를 import한다(Apple 플랫폼에서는 `Foundation`). 코어 `RIBs`, `TodoCore`, 피처 모듈은 지금처럼 Foundation 없이 둔다.
  - 층은 셋이다.
    - `HTTPTransport`(프로토콜): 요청을 보내고 응답을 받는다. `HTTPRequest`·`HTTPResponse`는 값 타입이고 본문은 `[UInt8]`이다. 실패는 `throws(HTTPTransportError)`. 플랫폼이 구현하는 것은 이것 하나다.
    - `TodoAPIClient`: 요청을 만들고, 상태 코드를 확인하고, `JSONDecoder`로 DTO를 읽어 `Todo`로 바꾼다. 실패 이유를 `TodoAPIError`로 구분한다.
    - `RemoteTodoRepository`: `TodoRepository`를 구현한다. 실패 이유를 피처가 쓰는 두 가지(`cancelled`, `unavailable`)로 줄인다.
  - `TodoRepository` 프로토콜과 `TodoRepositoryError`는 `TodoCore`에 둔다. 피처는 이 프로토콜만 알고 `TodoData`를 import하지 않는다. 구현은 `LoggedInDependency.todoRepository`로 주입한다(ADR-0005). `TodoData`를 아는 곳은 조립 모듈 `TodoAppRoot`와 전송 구현을 고르는 플랫폼 앱 타깃뿐이다. 경계 검사 스크립트가 "Foundation은 `TodoData`만", "피처는 `TodoData`를 import하지 않는다"를 확인한다(ADR-0028).
  - 목록을 불러오는 일은 TodoList 피처가 한다. `TodoStore`는 비어 있는 채로 시작하고(`TodoStore.unloaded()`), 목록 Interactor가 활성화될 때 저장소에서 불러와 채운다. `TodoListViewState`에 `isLoading`과 `errorMessage`를, `TodoListViewAction`에 `retryTapped`를 더한다. 요청은 활성 구간에 묶여 있어 화면이 내려가면 취소된다(ADR-0002).
  - 상태 복원은 목록보다 먼저 일어난다. 완료 표시는 `TodoStore`가 기억해 뒀다가 불러온 목록에 입히고, 열려 있던 상세는 LoggedIn Interactor가 목록이 채워진 뒤에 연다. 그 사이에 다시 저장해도 두 값은 그대로 저장된다.
  - 샘플 앱에는 서버가 없다. `TodoData`의 `SampleTodoServer`가 `HTTPTransport`를 구현해 JSON 본문을 돌려준다. `TodoApp`에 저장소를 주지 않으면 이것을 쓴다. iOS와 Web 앱은 UI 테스트용으로 처음 n번을 실패시키는 값(`-todoFailures`, `?todoFailures=`)을 받는다.
  - ADR-0017은 채택하지 않는다. 코어의 상태 저장 형식(`RibValue`, ADR-0018)은 이 결정과 따로 다룬다.
- 고려했던 대안:
  (1) Foundation 없이 DTO 디코딩을 손으로 짜기: 크기가 늘지 않는다. 대신 API마다 디코더를 손으로 쓰고 문자열 이스케이프·숫자 범위 같은 JSON 규칙을 직접 책임진다. 코어의 `RibStateCodec`은 저장 형식 하나만 다루지만 데이터 계층은 API가 늘 때마다 늘어난다. 기각했다.
  (2) ADR-0017대로 코어와 모든 공유 모듈에 허용: 코어를 쓰기만 하는 앱도 크기 비용을 낸다. 코어가 Foundation을 필요로 하는 곳은 상태 저장뿐이고 그 결정(ADR-0018)이 나지 않았다. 범위를 데이터 계층으로 좁혀 기각했다.
  (3) 디코딩까지 플랫폼에 맡기기(플랫폼이 `[Todo]`를 돌려주는 저장소를 구현): 응답 해석과 오류 분류가 플랫폼마다 따로 생긴다. 공유하려던 부분이라 기각했다.
  (4) `HTTPResponse.body`를 `Data`로: 전송 구현(Web의 `fetch` 결과 등)이 Foundation을 import해야 한다. `[UInt8]`로 두고 `TodoAPIClient` 안에서만 `Data`로 바꾼다.
  (5) 부모(LoggedIn)가 목록을 불러와 채운 뒤 자식을 붙이기: 로딩과 오류를 그릴 화면이 LoggedIn에 따로 필요하다. 목록 화면이 자기 데이터의 로딩을 그리는 쪽이 단순해 기각했다.
  (6) 이번에 실제 전송(`URLSession`, `fetch`, Android)까지 구현하기: 세 플랫폼의 테스트에 로컬 서버가 필요해 범위가 커진다. 전송 프로토콜 아래만 남기고 다음 작업으로 미뤘다.
- 결과:
  - 요청 생성, 상태 코드 확인, JSON 해석, 오류 분류, 로딩·재시도 흐름이 공유 코드에 있고 가짜 전송으로 테스트된다. 플랫폼이 만들 것은 `HTTPTransport` 구현 하나다.
  - `JSONDecoder`가 Wasm에서 도는 것은 Web e2e가 확인한다(앱이 샘플 서버의 JSON을 읽어 목록을 그린다).
  - Web 디버그 Wasm이 13.4MB에서 22.6MB가 됐다. 릴리스 크기는 이번에 다시 재지 않았다.
  - 실제 전송 구현은 없다. iOS `URLSession`, Web `fetch`, Android(OkHttp를 swift-java로 잇거나 `FoundationNetworking`)는 남은 일이다. Android 쪽 선택은 SDK를 확인한 뒤 정한다.
  - 복원 시 열려 있던 상세는 목록을 불러온 뒤에 열린다. 그 전까지는 목록의 로딩이 보인다. 불러오기에 실패하면 상세는 열리지 않고, 다시 시도에 성공하면 열린다.
  - Android 앱에는 실패 횟수를 받는 통로를 두지 않았다. 실패 화면은 순수 뷰의 Compose 테스트로만 확인한다.
  - 이슈가 든 `KeyValueStore`는 만들지 않았다. 쓰는 곳이 없다.
  - `LoginShared`를 쓰는 기본 샘플은 바뀌지 않는다.
- 관련: ADR-0002, ADR-0004, ADR-0005, ADR-0017, ADR-0018, ADR-0024, ADR-0025, ADR-0028
