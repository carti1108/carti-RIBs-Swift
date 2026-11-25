import JavaScriptEventLoop
import JavaScriptKit
import TodoData

/// 브라우저 `fetch`로 보내는 전송 계층(ADR-0033). 이 플랫폼이 데이터 계층에 대해 구현하는 것은 이것 하나다.
/// 본문은 텍스트로 받아 UTF-8 바이트로 넘긴다. 이 API의 본문은 JSON이다.
@MainActor
final class FetchHTTPTransport: HTTPTransport {
    private let baseURL: String

    /// `baseURL`은 요청 경로 앞에 붙는다(`/api` + `/todos`).
    init(baseURL: String) {
        self.baseURL = baseURL
    }

    func send(_ request: HTTPRequest) async throws(HTTPTransportError) -> HTTPResponse {
        // Task가 취소되면 요청도 끊는다. Wasm은 스레드가 하나라 취소 핸들러도 같은 스레드에서 돈다.
        nonisolated(unsafe) let abort = JSObject.global.AbortController.function!.new()
        let options = JSObject.global.Object.function!.new()
        options.method = .string(request.method.rawValue)
        options.signal = abort.signal
        let url = baseURL + request.path
        // `JSPromise.value`는 메인 액터 밖에서 도는 프로퍼티라 `JSValue`가 액터 경계를 넘는다.
        // 프로미스 콜백 안에서 `Sendable`한 결과로 바꿔 continuation으로 돌려준다.
        let result: Result<HTTPResponse, HTTPTransportError> = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard let fetched = JSObject.global.fetch.function!(url, options).object else {
                    continuation.resume(returning: .failure(.unreachable))
                    return
                }
                let status = StatusBox()
                _ = JSPromise(unsafelyWrapping: fetched)
                    .then(success: { response in
                        guard let response = response.object else { return .undefined }
                        status.code = response.status.number.map { Int($0) }
                        return response.text!()
                    })
                    .then(
                        success: { text in
                            if let code = status.code, let body = text.string {
                                continuation.resume(returning: .success(HTTPResponse(status: code, body: Array(body.utf8))))
                            } else {
                                continuation.resume(returning: .failure(.unreachable))
                            }
                            return .undefined
                        },
                        failure: { _ in
                            continuation.resume(returning: .failure(.unreachable))
                            return .undefined
                        }
                    )
            }
        } onCancel: {
            _ = abort.abort!()
        }
        // 끊긴 요청은 거절로 끝난다. 취소가 원인이면 취소로 알린다.
        if Task.isCancelled { throw .cancelled }
        return try result.get()
    }
}

/// 첫 콜백이 읽은 상태 코드를 다음 콜백에 넘긴다.
private final class StatusBox {
    var code: Int?
}
