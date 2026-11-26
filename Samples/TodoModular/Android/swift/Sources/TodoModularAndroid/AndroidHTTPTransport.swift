import TodoData

/// 요청을 실제로 보내는 쪽. Kotlin이 구현한 것을 브리지 타깃이 이 프로토콜로 감싼다.
@MainActor
public protocol AndroidHTTPSender: AnyObject {
    /// 요청을 시작한다. 결과는 나중에 `AndroidHTTPTransport.complete`나 `fail`로 돌려준다.
    /// `headers`는 `이름: 값` 줄을 `\n`으로 끝낸 문자열이고, `body`는 본문이 없으면 빈 문자열이다.
    func start(requestID: Int64, method: String, path: String, headers: String, body: String)
    func cancel(requestID: Int64)
}

/// Android의 전송 계층(ADR-0033). 요청은 Kotlin이 플랫폼 HTTP 스택으로 보내고, 응답이 오면 요청 id로 짝을 맞춘다.
/// 본문은 문자열로 받아 UTF-8 바이트로 넘긴다. 이 API의 본문은 JSON이다.
@MainActor
public final class AndroidHTTPTransport: HTTPTransport {
    private typealias Completion = CheckedContinuation<Result<HTTPResponse, HTTPTransportError>, Never>

    private let sender: any AndroidHTTPSender
    private var pending: [Int64: Completion] = [:]
    private var nextRequestID: Int64 = 1

    public init(sender: any AndroidHTTPSender) {
        self.sender = sender
    }

    public func send(_ request: HTTPRequest) async throws(HTTPTransportError) -> HTTPResponse {
        let requestID = nextRequestID
        nextRequestID += 1
        let result = await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: Completion) in
                guard !Task.isCancelled else {
                    continuation.resume(returning: .failure(.cancelled))
                    return
                }
                pending[requestID] = continuation
                sender.start(
                    requestID: requestID,
                    method: request.method.rawValue,
                    path: request.path,
                    headers: Self.headerLines(request.headers),
                    body: request.body ?? ""
                )
            }
        } onCancel: {
            Task { @MainActor in self.cancel(requestID) }
        }
        return try result.get()
    }

    /// 응답을 받았다. 상태 코드가 오류여도 이쪽으로 온다. 이미 끝난 요청이면 무시한다.
    public func complete(requestID: Int64, status: Int, body: String) {
        pending.removeValue(forKey: requestID)?.resume(returning: .success(HTTPResponse(status: status, body: Array(body.utf8))))
    }

    /// 응답을 받지 못했다(연결 실패, 시간 초과). 이미 끝난 요청이면 무시한다.
    public func fail(requestID: Int64) {
        pending.removeValue(forKey: requestID)?.resume(returning: .failure(.unreachable))
    }

    /// swift-java 경계는 문자열만 넘긴다(ADR-0020). 헤더를 이름순 `이름: 값\n` 줄로 묶는다.
    /// HTTP 헤더에는 줄바꿈이 들어갈 수 없어 줄 단위로 나눠도 섞이지 않는다.
    static func headerLines(_ headers: [String: String]) -> String {
        headers.sorted { $0.key < $1.key }.map { name, value in
            precondition(
                !name.isEmpty && !name.contains(where: \.isNewline) && !name.contains(":") && !value.contains(where: \.isNewline),
                "invalid HTTP header: \(name)"
            )
            return "\(name): \(value)\n"
        }.joined()
    }

    private func cancel(_ requestID: Int64) {
        guard let continuation = pending.removeValue(forKey: requestID) else { return }
        sender.cancel(requestID: requestID)
        continuation.resume(returning: .failure(.cancelled))
    }
}
