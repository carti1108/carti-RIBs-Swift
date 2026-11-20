// 내보내는 층. 격리 없는 타입만 public으로 두고, @MainActor 계약은 internal로 감춘다.

/// Kotlin 뷰가 구현한다.
public protocol LoggedOutViewBridge {
    func render(_ state: LoggedOutViewState)
}

/// Kotlin 뷰가 쥐고 입력을 보낸다.
public final class LoggedOutScreenHandle: @unchecked Sendable {
    private let box: MainBox

    public init(view: any LoggedOutViewBridge) {
        nonisolated(unsafe) let view = view
        box = onMain { MainBox(view: view) }
    }

    public func activate() { onMain { box.driver.activate() } }
    public func send(_ action: LoggedOutViewAction) { onMain { box.driver.handle(action) } }
    public func lastName() -> String { onMain { box.driver.lastName } }
}

@MainActor
private final class MainBox: LoginViewFactory {
    private let bridged: BridgedLoggedOutView
    private(set) var driver: LoggedOutDriver!

    init(view: any LoggedOutViewBridge) {
        bridged = BridgedLoggedOutView(view: view)
        driver = LoggedOutDriver(factory: self)
    }

    func makeLoggedOutView() -> any LoggedOutViewContract { bridged }
}

@MainActor
private final class BridgedLoggedOutView: LoggedOutViewContract {
    weak var listener: (any LoggedOutPresentableListener)?
    private let view: any LoggedOutViewBridge
    init(view: any LoggedOutViewBridge) { self.view = view }
    func render(_ state: LoggedOutViewState) { view.render(state) }
}

/// 실험 전용. 호출 스레드가 메인이라고 가정하고 격리 검사를 건너뛴다.
/// Android에서는 메인 루퍼 연결 뒤 `MainActor.assumeIsolated`로 바꿔야 한다.
private func onMain<T>(_ body: @MainActor () -> T) -> T {
    withoutActuallyEscaping(body) { unsafeBitCast($0, to: (() -> T).self)() }
}
