/// 활성 구간 밖에서 Task를 띄우려 할 때의 오류. AutoDispose `LifecycleNotStarted/EndedException`에 대응한다.
public enum LifecycleError: Error, Equatable, Sendable {
    /// 한 번도 활성화되지 않았다.
    case notStarted(owner: String)
    /// 활성 구간이 끝났다.
    case ended(owner: String)
}
