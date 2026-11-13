/// 활성 상태 구독을 끊는 핸들.
@MainActor
public final class ActiveObservation {
    private var onCancel: (() -> Void)?

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    /// 구독을 끊는다. 여러 번 불러도 한 번만 동작한다.
    public func cancel() {
        let action = onCancel
        onCancel = nil
        action?()
    }
}

/// Bool 상태와 동기 구독자 목록. Interactor와 Worker가 함께 쓴다.
@MainActor
final class ActiveState {
    private(set) var value = false
    private var observers: [UInt64: (Bool) -> Void] = [:]
    private var nextID: UInt64 = 0

    func set(_ newValue: Bool) {
        guard value != newValue else { return }
        value = newValue
        for handler in observers.sorted(by: { $0.key < $1.key }).map(\.value) {
            handler(newValue)
        }
    }

    /// 현재 값을 바로 전달하고, 바뀔 때마다 다시 전달한다.
    func observe(_ handler: @escaping @MainActor (Bool) -> Void) -> ActiveObservation {
        let id = nextID
        nextID += 1
        observers[id] = handler
        handler(value)
        return ActiveObservation { [weak self] in self?.observers[id] = nil }
    }

    /// 현재 값을 먼저 보내고 바뀔 때만 다시 보내는 스트림.
    func stream() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let observation = observe { continuation.yield($0) }
            continuation.onTermination = { _ in
                Task { @MainActor in observation.cancel() }
            }
        }
    }
}
