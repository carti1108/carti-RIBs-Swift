import TodoData

/// 응답 시점과 내용을 테스트가 정하는 전송 계층.
@MainActor
final class FakeHTTPTransport: HTTPTransport {
    private(set) var requests: [HTTPRequest] = []
    private var pending: CheckedContinuation<Result<HTTPResponse, HTTPTransportError>, Never>?

    func send(_ request: HTTPRequest) async throws(HTTPTransportError) -> HTTPResponse {
        requests.append(request)
        let result = await withTaskCancellationHandler {
            await withCheckedContinuation { pending = $0 }
        } onCancel: {
            Task { @MainActor in self.respond(.failure(.cancelled)) }
        }
        return try result.get()
    }

    func respond(_ result: Result<HTTPResponse, HTTPTransportError>) {
        pending?.resume(returning: result)
        pending = nil
    }

    func respond(status: Int = 200, json: String) {
        respond(.success(HTTPResponse(status: status, body: Array(json.utf8))))
    }
}
