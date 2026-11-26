### ADR-0036 401은 저장소 오류 `unauthorized`로 피처에 올리고, 토큰 갱신은 `BearerTokenTransport`가 한 번만 한다
- 상태: 채택
- 날짜: 2026-11-26
- 배경:
  - ADR-0034 이후 `TodoAPIClient`는 401을 `unauthorized`로 구분하지만 `RemoteTodoRepository`가 모든 실패를 `unavailable`로 줄였다. 피처는 토큰 만료에도 "불러오지 못했습니다"와 다시 시도 버튼만 보여 줬고, 다시 시도해도 같은 401이 났다.
  - `BearerTokenTransport`는 토큰 갱신과 401 뒤 재시도를 하지 않았다(ADR-0034 결과). 실제 앱은 짧은 접근 토큰과 갱신 토큰을 쓰는 경우가 많다.
- 결정:
  - `TodoRepositoryError`에 `unauthorized`를 더한다. `RemoteTodoRepository`는 API의 `unauthorized`만 이것으로 바꾸고, 나머지 실패는 여전히 `unavailable`이다.
  - TodoList는 `unauthorized`를 받으면 오류 문구를 띄우지 않고 로딩만 끈 뒤 `TodoListListener.didRequireSignIn()`으로 부모에게 넘긴다. LoggedIn은 이것을 로그아웃 버튼과 같은 `didRequestLogout()` 경로로 보낸다.
  - `BearerTokenTransport.init`에 선택 인자 `refresh: @MainActor () async -> String?`을 더한다. 토큰을 붙여 보낸 요청이 401을 받으면:
    - 지금 `token()`이 거절된 토큰과 다르면 갱신하지 않고 지금 토큰으로 다시 보낸다(다른 요청이 이미 갱신했다).
    - 갱신 중이면 진행 중인 갱신 결과를 기다린다. 갱신은 동시에 하나만 돈다.
    - 아니면 `refresh`를 부른다. nil이면 원래 401을 돌려준다.
    - 다시 보내는 것은 한 번뿐이다. 다시 401이면 그대로 돌려주고 `TodoAPIClient`가 `unauthorized`로 알린다.
  - 토큰 저장은 플랫폼이 한다. `refresh`는 새 토큰을 돌려주면서 이후 `token`이 그 값을 돌려주게 해야 한다.
- 고려했던 대안:
  (1) `unauthorized`를 `TodoListViewState`의 문구로만 보여 주기: 사용자가 직접 로그아웃해야 하고, 다시 시도 버튼은 의미가 없다. 로그인으로 돌려보내는 것은 부모(LoggedIn)의 책임이라 리스너로 올렸다.
  (2) LoggedIn이 저장소를 직접 보고 401을 감지하기: LoggedIn은 저장소를 모른다(ADR-0032에서 TodoList만 `TodoRepository`를 받는다). 감지는 요청한 피처가 하고 결정은 부모가 하는 RIBs의 리스너 방향을 따랐다.
  (3) `TodoListListener`에 `didRequestLogout()`을 그대로 두기: 사용자의 로그아웃과 인증 거절은 지금은 같은 경로지만, 앱이 "세션이 만료됐습니다" 안내를 띄우려면 구분해야 한다. 이름을 원인으로 붙였다.
  (4) 토큰 갱신을 `TodoAPIClient`에 두기: 갱신은 API마다 같은 일이고 전송 수준의 관심사다. 클라이언트에 두면 API 클라이언트마다 같은 코드가 생긴다. 인증 헤더를 붙이는 `BearerTokenTransport`가 이미 토큰을 다루므로 함께 뒀다.
  (5) 갱신 뒤 여러 번 재시도하기: 새 토큰도 거절되면 서버가 세션을 끊은 것이다. 계속 갱신하면 갱신 토큰 엔드포인트를 반복해서 친다. 한 번으로 둔다.
  (6) 갱신한 토큰을 `BearerTokenTransport` 안에 저장하기: 토큰의 원본이 둘이 되어 플랫폼 저장소(키체인 등)와 어긋날 수 있다. 원본은 플랫폼 하나로 둔다.
- 결과:
  - 샘플 앱에는 인증 서버가 없어 `refresh`를 쓰는 조립 코드는 없다. 쓰기 요청 스파이크(ADR-0034)도 `refresh` 없이 쓴다. 동작은 `TodoData`의 `BearerTokenRefreshTests`(갱신·재시도 한 번·갱신 실패·토큰 없는 요청·403·동시 401의 갱신 하나·늦게 온 옛 토큰의 401)가 확인한다.
  - `TodoListListener`에 메서드가 하나 늘어 플랫폼 데모(Web `FeatureDemo`, Android `FeatureDemoController`, iOS `TodoListExampleHarness`)도 구현한다. 데모는 이벤트 이름만 보여 준다.
  - 쓰기 요청(`createTodo`)의 401은 아직 피처까지 오지 않는다. 쓰기를 쓰는 피처가 생기면 같은 방식으로 저장소 오류를 쓴다.
  - 갱신 중에 요청 Task가 취소되면 갱신은 끝까지 돌고(다른 요청이 기다릴 수 있다), 취소된 요청은 다시 보내지 않고 `cancelled`를 던진다.
- 관련: ADR-0032, ADR-0034
