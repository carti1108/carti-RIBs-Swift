/// 취소될 때까지 멈춘다. 시간에 기대지 않는다(AsyncStream 반복은 취소되면 끝난다).
func suspendUntilCancelled() async {
    let (stream, continuation) = AsyncStream<Never>.makeStream()
    for await _ in stream {}
    withExtendedLifetime(continuation) {}
}

/// 메인 액터에 쌓인 다른 Task가 먼저 돌도록 양보한다.
@MainActor
func drainMainActor(rounds: Int = 10) async {
    for _ in 0..<rounds { await Task.yield() }
}

extension AsyncStream {
    /// 앞에서부터 `count`개를 읽는다. 버퍼된 값만 읽으므로 기다림 없이 끝난다.
    func take(_ count: Int, isolation: isolated (any Actor)? = #isolation) async -> [Element] {
        var result: [Element] = []
        guard count > 0 else { return result }
        for await value in self {
            result.append(value)
            if result.count == count { break }
        }
        return result
    }
}
