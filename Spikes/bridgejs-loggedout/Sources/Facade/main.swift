import JavaScriptKit

// 내보내는 층. 값 타입과 격리 없는 타입만 @JS 로 둔다.
@JS public struct LoggedOutViewState: Equatable, Sendable {
    public var errorMessage: String?
    public var isLoading: Bool
    @JS public init(errorMessage: String? = nil, isLoading: Bool = false) {
        self.errorMessage = errorMessage
        self.isLoading = isLoading
    }
}

@JS public enum LoggedOutViewAction: Equatable, Sendable {
    case loginTapped(rawName: String)
}

/// 웹 뷰가 구현한다.
@JS public protocol LoggedOutViewBridge {
    func render(_ state: LoggedOutViewState)
}

/// 웹 뷰가 쥐고 입력을 보낸다.
@JS public final class LoggedOutScreenHandle: @unchecked Sendable {
    private let box: MainBox

    @JS public init(view: any LoggedOutViewBridge) {
        nonisolated(unsafe) let view = view
        box = onMain { MainBox(view: view) }
    }

    @JS public func activate() { onMain { box.driver.activate() } }
    @JS public func send(_ action: LoggedOutViewAction) { onMain { box.driver.handle(action) } }
    @JS public func lastName() -> String { onMain { box.driver.lastName } }
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

/// 실험 전용. 격리 검사를 건너뛴다. Wasm 은 단일 스레드라 실제로는 `MainActor.assumeIsolated` 로 바꾼다.
private func onMain<T>(_ body: @MainActor () -> T) -> T {
    withoutActuallyEscaping(body) { unsafeBitCast($0, to: (() -> T).self)() }
}
