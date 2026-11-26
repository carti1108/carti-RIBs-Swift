import TodoData

/// 응답 시점과 내용을 테스트가 정하는 전송 계층. 기다리는 요청이 여럿이면 먼저 온 요청부터 응답한다.
@MainActor
final class FakeHTTPTransport: HTTPTransport {
    private(set) var requests: [HTTPRequest] = []
    private var pending: [CheckedContinuation<Result<HTTPResponse, HTTPTransportError>, Never>] = []

    func send(_ request: HTTPRequest) async throws(HTTPTransportError) -> HTTPResponse {
        requests.append(request)
        let result = await withTaskCancellationHandler {
            await withCheckedContinuation { pending.append($0) }
        } onCancel: {
            Task { @MainActor in self.respond(.failure(.cancelled)) }
        }
        return try result.get()
    }

    /// 가장 먼저 기다리기 시작한 요청에 응답한다. 기다리는 요청이 없으면 아무것도 하지 않는다.
    func respond(_ result: Result<HTTPResponse, HTTPTransportError>) {
        guard !pending.isEmpty else { return }
        pending.removeFirst().resume(returning: result)
    }

    func respond(status: Int = 200, json: String) {
        respond(.success(HTTPResponse(status: status, body: Array(json.utf8))))
    }
}
