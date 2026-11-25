### ADR-0034 쓰기 요청과 인증 헤더는 공유 코드가 만들고, 전송 계층은 메서드·헤더·본문을 그대로 보낸다
- 상태: 채택
- 날짜: 2026-11-25
- 배경:
  - 그렙 클라이언트가 이 라이브러리를 공통 코어로 쓰기로 했다(#31). ADR-0033이 검증한 것은 같은 출처의 `GET /api/todos`와 재시도뿐이다. 그렙에는 쓰기 요청, `Authorization: Bearer` 헤더, 웹과 다른 주소의 API 서버, RFC 9457 Problem Details 오류 본문이 필요하다.
  - `HTTPRequest`에는 메서드 `GET`과 경로만 있었다. 헤더와 본문을 넣으면 세 플랫폼 전송이 모두 그것을 보내야 한다.
  - 브라우저는 CORS 검사에 실패한 요청을 네트워크 오류로 처리하고, `fetch`는 둘 다 같은 `TypeError`로 거절한다(Fetch Standard, "CORS check" 실패는 network error). 페이지 코드는 원인을 볼 수 없다.
- 결정:
  - `HTTPRequest`에 메서드 `POST`·`PATCH`·`DELETE`, `headers: [String: String]`, `body: String?`를 둔다. 본문은 UTF-8 텍스트(JSON)만 싣는다. Android·Web 경계가 문자열만 넘기기 때문이다. 기본값이 있어 기존 `HTTPRequest(method:path:)` 호출은 그대로다.
  - 전송 구현은 메서드·헤더·본문을 받은 그대로 보낸다.
    - iOS: `URLRequest`의 헤더와 `httpBody`.
    - Web: `fetch` 옵션의 `headers`와 `body`.
    - Android: swift-java 경계의 `start`에 `headers: String`, `body: String`을 더한다. 헤더는 Swift(`AndroidHTTPTransport.headerLines`)가 이름순 `이름: 값\n` 줄로 묶고, Kotlin이 줄을 나눠 `setRequestProperty`로 넣는다. 본문이 없으면 빈 문자열이고, Kotlin은 빈 본문을 쓰지 않는다. 인자는 여전히 `Int64`, `Int32`, `String`뿐이다(ADR-0020).
  - 인증은 공유 데이터 계층의 `BearerTokenTransport`가 붙인다. 다른 `HTTPTransport`를 감싸고, 보낼 때마다 플랫폼이 준 `token` 클로저를 불러 nil이 아니면 `Authorization: Bearer <토큰>`을 더한다. 플랫폼 전송은 인증을 모른다.
  - `TodoAPIClient`가 상태 코드를 분류한다. 401은 `unauthorized(problem:)`, 409는 `conflict(problem:)`, 그 밖의 2xx가 아닌 상태는 `badStatus(_:problem:)`다. 오류 본문이 JSON 객체면 `ProblemDetails`(표준 멤버 `type`·`title`·`status`·`detail`·`instance`, `type`이 없으면 `about:blank`)로 읽고, 비었거나 객체가 아니면 nil이다. 쓰기 API로 `createTodo(title:)`(`POST /todos`)를 둔다.
  - CORS 거부는 `unreachable`로 둔다. 따로 분류하지 않는다.
  - 검증은 웹 스파이크로 한다. `spikes/write-request.html`이 `runWriteRequestSpike(baseURL:token:title:)`를 불러 다른 출처의 API에 `POST /todos`를 보내고, 공유 코드가 분류한 결과를 `#result`에 쓴다. 화면과 피처는 바꾸지 않는다.
- 고려했던 대안:
  (1) 플랫폼 전송이 토큰을 받아 헤더를 붙이기: 세 플랫폼에 같은 코드가 생기고, 토큰을 읽는 시점이 플랫폼마다 달라진다. 공유 데코레이터 하나로 두면 플랫폼은 "보내고 받은 것을 돌려준다"만 하는 ADR-0033의 경계가 유지된다. 기각했다.
  (2) CORS 거부를 별도 오류로 분류하기: 브라우저가 원인을 숨겨 페이지에서 구분할 방법이 없다. `navigator.onLine` 같은 추정은 연결이 살아 있어도 서버가 죽은 경우와 섞인다. 기각했다. CORS 설정은 서버 배포 체크리스트로 다룬다.
  (3) 요청 본문을 `[UInt8]`로 두기: 응답과 모양은 맞지만 Android·Web 경계에서 다시 문자열로 바꿔야 하고, UTF-8이 아닌 바이트는 그때 깨진다. 실제 제약을 타입에 드러내려고 `String`으로 뒀다.
  (4) 응답 헤더를 넘겨 `Content-Type: application/problem+json`을 확인하기: 세 플랫폼 전송과 Android 경계가 모두 바뀐다. JSON 객체가 아닌 오류 본문(HTML 오류 페이지 등)은 디코딩에서 걸러진다. 응답 헤더가 다른 이유로 필요해질 때 함께 넣는다.
  (5) 할 일 추가 화면을 세 플랫폼에 만들어 검증하기: 피처·뷰 계약·플랫폼 뷰가 모두 바뀐다. 이 ADR이 확인할 것은 전송 경로라 스파이크로 충분하다.
  (6) Android 헤더를 JSON 문자열로 넘기기: Kotlin에서 JSON 파서가 필요하다. HTTP 헤더에는 줄바꿈이 들어갈 수 없어 줄 단위로 나누면 섞이지 않는다. 줄바꿈이나 `:`가 든 이름, 줄바꿈이 든 값은 `precondition`으로 막는다.
- 결과:
  - Web e2e(`e2e/write-request.test.js`)가 앱(`127.0.0.1`)과 다른 출처(`localhost`, 다른 포트)의 테스트 서버로 확인한다. 브라우저가 `Authorization`을 보고 프리플라이트(OPTIONS)를 먼저 보내고, 이어서 `Authorization: Bearer`, `Content-Type: application/json`, JSON 본문으로 POST한다. 201 응답의 할 일, 토큰이 없을 때의 401, 401·409·503의 Problem Details `title`, HTML 오류 본문(문제 없음)이 공유 코드에서 분류된다. 서버가 CORS를 허용하지 않으면 POST는 나가지 않고 `unreachable`이 된다. 스파이크의 `runTransportSpike`로 요청을 그대로 보내 PATCH(본문 포함)와 본문 없는 DELETE(`Content-Type`·본문 없음)도 확인했다. 프리플라이트가 PATCH를 허용하지 않으면 PATCH는 나가지 않고 `unreachable`이 된다.
  - Android 계측 테스트(`HttpUrlConnectionTransportTest`)가 기기 안의 테스트 서버로 `HttpUrlConnectionTransport`를 확인한다. Swift가 넘기는 모양의 헤더 줄과 본문으로 POST(UTF-8 한글 본문 포함), PATCH, 본문 없는 DELETE가 그대로 나가고, `: `가 든 헤더 값도 깨지지 않는다.
  - iOS는 `URLProtocol` 가짜로 POST 헤더·본문, PATCH 본문, 본문 없는 DELETE를 확인한다. 실제 소켓 경로는 `URLSessionHTTPTransportLoopbackTests`가 시뮬레이터 테스트 프로세스 안의 `NWListener` 서버로 확인한다. `BearerTokenTransport`와 `TodoAPIClient.createTodo`를 거친 POST(UTF-8 한글 본문, `Authorization: Bearer`), 401 Problem Details, PATCH 본문, 본문 없는 DELETE가 그대로 오간다. 시뮬레이터에서 `http://127.0.0.1`로 보낼 때 ATS 예외는 필요 없었다.
  - API 서버는 `Access-Control-Allow-Origin`과, 프리플라이트에 `Access-Control-Allow-Headers: Authorization, Content-Type`을 줘야 한다. 빠지면 앱은 "연결할 수 없음"만 안다.
  - `RemoteTodoRepository`는 새 오류 셋도 `unavailable`로 줄인다. 피처가 401을 따로 다루려면 `TodoRepositoryError`를 넓혀야 한다. 이 ADR은 하지 않는다.
  - 토큰 갱신과 401 뒤 재시도는 없다. 그렙에서 필요하면 `BearerTokenTransport` 자리에서 다룬다.
  - 바이너리 본문은 이 경로로 보낼 수 없다. 경계마다 바이트를 넘길 수 있는지 소스로 확인했다(실행하지는 않았다).
    - Web: `FetchHTTPTransport`는 BridgeJS를 거치지 않고 JavaScriptKit을 직접 쓴다. `JSTypedArray<UInt8>`(`JSUint8Array`)의 `init(_: [UInt8])`과 `withUnsafeBytes`로 `Uint8Array`와 `[UInt8]`을 오갈 수 있다(JavaScriptKit 0.63.0 `BasicObjects/JSTypedArray.swift`). BridgeJS `@JS` 시그니처도 `JSTypedArray<UInt8>`을 `Uint8Array`로 넘긴다(`Supported-Types.md`). `[UInt8]`은 원소마다 넘기는 JS 배열이 된다.
    - Android: Kotlin이 부르는 Swift 메서드는 `[UInt8]`을 Java `byte[]`로 받는다(swift-java 0.7.0 `Tests/JExtractSwiftTests/ByteArrayTests.swift`의 JNI 경우). 응답 본문(`HTTPTransportHandle.complete`)은 바이트로 바꿀 수 있다. Kotlin이 구현하는 Swift 프로토콜(`HTTPTransportBridge`)의 바이트 배열 인자는 테스트도 생성 코드도 찾지 못했다. 요청 본문을 바이트로 보내려면 이것부터 확인하거나 base64 문자열로 넘긴다.
    - 서명된 URL로 뷰가 직접 올리는 구조는 이 경계를 거치지 않는다. 어느 쪽으로 할지는 그렙의 업로드 API가 정해지면 정한다.
  - Problem Details 멤버의 타입이 틀리면 그 멤버만 버리고 나머지는 읽는다(RFC 9457 §3.1).
  - Android는 빈 문자열 본문을 본문 없음으로 보낸다. iOS·Web은 빈 본문을 보낸다. 지금 공유 코드는 빈 본문을 만들지 않는다.
  - Android `HttpURLConnection`의 PATCH는 Android 런타임 구현에서는 나간다(위 계측 테스트). 표준 JVM 구현은 `ProtocolException`을 던져 `unreachable`이 되므로, 브리지를 JVM에서 돌리게 되면 OkHttp로 바꾼다.
- 관련: ADR-0020, ADR-0032, ADR-0033
