import RIBs

/// 샘플이 기다릴 때 쓰는 시계. 테스트는 시간을 직접 넘기는 가짜를 넣어 실제로 자지 않는다.
@MainActor
public protocol LoginClock: AnyObject {
    /// `duration`만큼 기다린다. 기다리는 Task가 취소되면 `CancellationError`를 던진다.
    func sleep(for duration: Duration) async throws(CancellationError)
}

/// `Task.sleep`으로 기다리는 실제 시계.
@MainActor
public final class TaskSleepClock: LoginClock {
    public init() {}

    public func sleep(for duration: Duration) async throws(CancellationError) {
        do {
            try await Task.sleep(for: duration)
        } catch {
            throw CancellationError()
        }
    }
}

extension Interactor {
    /// 활성 구간에 묶인 Task를 띄운다. 활성 구간 밖에서 부르는 것은 샘플 코드의 버그라 실패시킨다.
    @discardableResult
    func startTask(_ operation: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        do {
            return try task(operation)
        } catch {
            preconditionFailure("\(type(of: self)) started a task outside its active scope: \(error)")
        }
    }
}

extension Worker {
    @discardableResult
    func startTask(_ operation: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        do {
            return try task(operation)
        } catch {
            preconditionFailure("\(type(of: self)) started a task outside its started scope: \(error)")
        }
    }
}
