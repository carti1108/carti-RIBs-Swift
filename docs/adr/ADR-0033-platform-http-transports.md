### ADR-0033 전송 계층은 플랫폼의 HTTP 스택으로 구현하고, Android는 Kotlin이 보내고 Swift가 결과를 받는다
- 상태: 채택
- 날짜: 2026-11-25
- 배경:
  - ADR-0032는 데이터 계층을 공유 모듈에 두고 플랫폼이 만들 것을 `HTTPTransport` 구현 하나로 줄였다. 실제 구현은 미뤘고, 샘플 앱은 앱 안의 `SampleTodoServer`를 썼다. 요청이 실제로 나가고 응답이 공유 코드까지 오는 경로는 확인되지 않았다.
  - Android에서는 방법이 둘이다. Android Swift SDK에는 `FoundationNetworking`(`URLSession`)이 들어 있다. 이 샘플은 이미 swift-java로 Kotlin을 부를 수 있다.
  - SDK(swift-6.4.2-RELEASE_android, aarch64)의 라이브러리 크기를 쟀다. `URLSession`을 쓰려면 `libFoundationNetworking.so` 15.7MB, `libFoundation.so` 8.6MB, `libFoundationInternationalization.so` 3.6MB, `lib_FoundationICU.so` 43.7MB가 더 들어간다. 합쳐 약 72MB다. 지금 싣는 `libFoundationEssentials.so`는 10.0MB다.
- 결정:
  - iOS: `URLSessionHTTPTransport`(`iOS/Transport`, Tuist 타깃 `TodoTransport`). 상태 코드와 본문을 그대로 돌려주고, 연결 실패는 `unreachable`, Task 취소는 `cancelled`로 던진다. 앱은 `-todoBaseURL <주소>` 실행 인자가 있을 때 이것을 쓰고, 없으면 `SampleTodoServer`를 쓴다.
  - Web: `FetchHTTPTransport`(`TodoModularWeb`). `fetch`로 같은 출처의 `/api/todos`를 읽는다. Task가 취소되면 `AbortController`로 요청을 끊는다. 앱은 항상 이것을 쓴다. 개발 서버와 빌드 결과에는 정적 JSON(`public/api/todos`)이 있다. `?todoFailures=`는 없앤다.
  - Android: Kotlin이 `HttpURLConnection`으로 보낸다.
    - Swift `AndroidHTTPTransport`(`TodoModularAndroid`)가 요청마다 id를 매겨 `AndroidHTTPSender.start`를 부르고 기다린다. 결과가 `complete(requestID:status:body:)`나 `fail(requestID:)`로 오면 id로 짝을 맞춘다. Task가 취소되면 `cancel`을 부르고 `cancelled`로 끝낸다. 이미 끝난 요청의 결과는 무시한다.
    - 브리지 타깃의 `HTTPTransportBridge`(Kotlin이 구현)와 `HTTPTransportHandle`(Kotlin이 부름)이 swift-java 경계다. 인자는 `Int64`, `Int32`, `String`뿐이다(ADR-0020).
    - Kotlin `HttpUrlConnectionTransport`(`:bridge`)는 백그라운드 스레드에서 보내고 메인 스레드에서 핸들을 부른다. Swift 쪽은 다른 핸들처럼 `MainActor.assumeIsolated`로 받는다.
    - 앱은 인텐트 값 `todoBaseUrl`이 있을 때 `SwiftBridge.installHttpTransport`로 넣고, 없으면 `SampleTodoServer`를 쓴다.
  - 세 플랫폼 모두 본문을 텍스트로 받아 UTF-8 바이트로 넘긴다(iOS는 바이트 그대로). 이 API의 본문은 JSON이다.
  - 요청 생성, 상태 코드 해석, JSON 디코딩, 오류 분류는 공유 코드에 그대로 있다. 플랫폼 구현은 "보내고 받은 것을 돌려준다"만 한다.
- 고려했던 대안:
  (1) Android에서 `FoundationNetworking`의 `URLSession` 쓰기: iOS 구현을 거의 그대로 쓸 수 있다. 대신 ABI마다 라이브러리 약 72MB가 늘고, 플랫폼의 인증서 저장소·프록시·네트워크 보안 설정을 따르지 않는다(swift-corelibs-foundation은 curl을 쓴다. 인증서 묶음 설정이 따로 필요한지는 확인하지 않았다). 기각했다.
  (2) Android에서 OkHttp 쓰기: 의존성이 하나 는다. 이 샘플의 요청은 GET 하나라 `HttpURLConnection`으로 충분하다. 실제 앱은 `HTTPTransportBridge` 구현만 바꾸면 된다.
  (3) Kotlin이 백그라운드 스레드에서 Swift 핸들을 바로 부르고 Swift가 메인 액터로 넘기기: 다른 스레드에서 넣은 작업이 메인 Looper를 깨우는지는 ADR-0014의 확인 범위 밖이다. 메인 스레드에서 부르게 해 기존 핸들과 같은 규칙으로 뒀다.
  (4) 본문을 바이트 배열로 넘기기: swift-java 0.7.0과 BridgeJS에서 바이트 배열 인자가 되는지 확인하지 않았다. 본문이 JSON인 동안은 문자열로 충분하다. 바이너리 응답이 필요해지면 다시 본다.
  (5) iOS와 Android 앱도 항상 실제 전송 쓰기: 샘플에 서버가 없어 앱을 그냥 띄우면 목록이 실패한다. Web만 자기 출처의 정적 파일을 읽을 수 있어 항상 쓰고, 나머지는 주소를 줬을 때만 쓴다.
- 결과:
  - Web e2e는 테스트 서버의 `/api/todos`로 실제 요청을 보낸다. 서버 503과 네트워크 끊김 뒤 다시 시도가 통과한다.
  - Android 계측 테스트는 기기 안의 테스트 서버(`ServerSocket`)에 `HttpURLConnection`으로 요청하고, 받은 JSON을 Swift 공유 코드가 읽어 목록을 그린다. 디버그 빌드 매니페스트에만 평문 HTTP를 허용한다. `:bridge` 매니페스트에 `INTERNET` 권한이 생긴다.
  - iOS는 `URLProtocol` 가짜로 `URLSessionHTTPTransport`를 단위 테스트한다. 앱이 서버에 붙는 UI 테스트는 없다.
  - Android와 Web은 본문을 문자열로 넘기므로 UTF-8이 아닌 본문은 깨진다.
  - `SampleTodoServer`는 iOS·Android 앱의 기본값과 테스트용으로 남는다.
  - Android에서 요청을 취소하면 결과는 버려지지만 연결은 바로 끊기지 않는다. 워커 스레드는 타임아웃(연결·읽기 각 10초)까지 남을 수 있다.
  - ADR-0032 결정 가운데 "Web 앱은 `?todoFailures=`를 받는다"는 이 ADR이 대체한다. Web 실패 경로는 테스트 서버가 만든다.
- 관련: ADR-0014, ADR-0020, ADR-0021, ADR-0032
