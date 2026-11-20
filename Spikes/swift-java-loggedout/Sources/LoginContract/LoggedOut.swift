// carti-RIBs-Swift Samples/LoginShared/Sources/LoggedOut.swift 의 뷰 계약을 그대로 옮긴 것.
@MainActor protocol Presentable: AnyObject {}
@MainActor protocol ViewControllable: AnyObject {}

public struct LoggedOutViewState: Equatable, Sendable {
    public var errorMessage: String?
    public var isLoading: Bool
    public init(errorMessage: String? = nil, isLoading: Bool = false) {
        self.errorMessage = errorMessage
        self.isLoading = isLoading
    }
}

public enum LoggedOutViewAction: Equatable, Sendable {
    case loginTapped(rawName: String)
}

@MainActor
protocol LoggedOutPresentableListener: AnyObject {
    func handle(_ action: LoggedOutViewAction)
}

@MainActor
protocol LoggedOutPresentable: Presentable {
    var listener: (any LoggedOutPresentableListener)? { get set }
    func render(_ state: LoggedOutViewState)
}

@MainActor protocol LoggedOutViewControllable: ViewControllable {}
@MainActor protocol LoggedOutViewContract: LoggedOutPresentable, LoggedOutViewControllable {}

@MainActor
protocol LoginViewFactory: AnyObject {
    func makeLoggedOutView() -> any LoggedOutViewContract
}

/// 공유 코드 쪽 역할: 팩토리에서 뷰를 받아 리스너를 걸고 상태를 그리게 한다.
@MainActor
final class LoggedOutDriver: LoggedOutPresentableListener {
    private let view: any LoggedOutViewContract
    private(set) var lastName: String = ""

    init(factory: any LoginViewFactory) {
        self.view = factory.makeLoggedOutView()
    }

    func activate() {
        view.listener = self
        view.render(LoggedOutViewState(errorMessage: nil, isLoading: false))
    }

    func handle(_ action: LoggedOutViewAction) {
        switch action {
        case .loginTapped(let rawName):
            lastName = rawName
            view.render(LoggedOutViewState(errorMessage: rawName.isEmpty ? "이름을 입력하세요" : nil, isLoading: !rawName.isEmpty))
        }
    }
}
