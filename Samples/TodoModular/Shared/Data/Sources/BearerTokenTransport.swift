/// 요청마다 `Authorization: Bearer <토큰>`을 붙여 다른 전송에 넘긴다.
/// 토큰은 플랫폼이 가진다(로그인 결과, 키체인 등). 이 타입은 보낼 때마다 `token`을 불러 그 값을 쓴다.
/// `token`이 nil이면 헤더 없이 보낸다.
///
/// `refresh`를 주면 토큰을 붙여 보낸 요청이 401을 받았을 때 토큰을 갱신하고 그 요청을 한 번만 다시 보낸다(ADR-0036).
/// - 갱신 중에 401을 받은 다른 요청은 새로 갱신하지 않고 진행 중인 갱신을 기다린다.
/// - 거절된 토큰과 지금 `token`이 다르면(다른 요청이 이미 갱신했으면) 갱신하지 않고 지금 토큰으로 다시 보낸다.
/// - `refresh`가 nil을 돌려주거나 다시 보낸 요청도 401이면 그 401을 그대로 돌려준다. `TodoAPIClient`가 `unauthorized`로 알린다.
/// `refresh`는 새 토큰을 돌려주는 것과 함께 이후 `token`이 그 값을 돌려주게 해야 한다. 저장은 플랫폼이 한다.
@MainActor
public final class BearerTokenTransport: HTTPTransport {
    public typealias Refresh = @MainActor () async -> String?

    private static let unauthorizedStatus = 401

    private let base: any HTTPTransport
    private let token: @MainActor () -> String?
    private let refresh: Refresh?
    private var refreshing: Task<String?, Never>?

    public init(base: any HTTPTransport, token: @escaping @MainActor () -> String?, refresh: Refresh? = nil) {
        self.base = base
        self.token = token
        self.refresh = refresh
    }

    public func send(_ request: HTTPRequest) async throws(HTTPTransportError) -> HTTPResponse {
        let sentToken = token()
        let response = try await send(request, token: sentToken)
        guard response.status == Self.unauthorizedStatus, let sentToken, refresh != nil else { return response }
        guard let renewed = await renewedToken(replacing: sentToken) else { return response }
        if Task.isCancelled { throw .cancelled }
        return try await send(request, token: renewed)
    }

    private func send(_ request: HTTPRequest, token: String?) async throws(HTTPTransportError) -> HTTPResponse {
        guard let token else { return try await base.send(request) }
        return try await base.send(request.setting(header: "Authorization", to: "Bearer \(token)"))
    }

    /// 거절된 토큰 대신 쓸 토큰. 이미 바뀌었으면 그 값을, 갱신 중이면 그 결과를, 아니면 새로 갱신한 결과를 돌려준다.
    private func renewedToken(replacing rejected: String) async -> String? {
        if let current = token(), current != rejected { return current }
        if let refreshing { return await refreshing.value }
        guard let refresh else { return nil }
        let task = Task { await refresh() }
        refreshing = task
        let renewed = await task.value
        refreshing = nil
        return renewed
    }
}
