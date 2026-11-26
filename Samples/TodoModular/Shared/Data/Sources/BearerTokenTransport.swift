/// 요청마다 `Authorization: Bearer <토큰>`을 붙여 다른 전송에 넘긴다.
/// 토큰은 플랫폼이 가진다(로그인 결과, 키체인 등). 이 타입은 보낼 때마다 `token`을 불러 그 값을 쓴다.
/// `token`이 nil이면 헤더 없이 보낸다. 토큰 갱신과 401 뒤 재시도는 하지 않는다. 401은 `TodoAPIClient`가 `unauthorized`로 알린다.
@MainActor
public final class BearerTokenTransport: HTTPTransport {
    private let base: any HTTPTransport
    private let token: @MainActor () -> String?

    public init(base: any HTTPTransport, token: @escaping @MainActor () -> String?) {
        self.base = base
        self.token = token
    }

    public func send(_ request: HTTPRequest) async throws(HTTPTransportError) -> HTTPResponse {
        guard let token = token() else { return try await base.send(request) }
        return try await base.send(request.setting(header: "Authorization", to: "Bearer \(token)"))
    }
}
