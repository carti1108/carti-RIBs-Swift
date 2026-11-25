import JavaScriptKit

// carti-RIBs-Swift Samples/LoginShared/Sources/LoggedOut.swift 의 뷰 계약에 @JS만 붙인 것.
@MainActor public protocol Presentable: AnyObject {}
@MainActor public protocol ViewControllable: AnyObject {}

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

@MainActor
@JS public protocol LoggedOutPresentableListener: AnyObject {
    func handle(_ action: LoggedOutViewAction)
}

@MainActor
@JS public protocol LoggedOutPresentable: Presentable {
    var listener: (any LoggedOutPresentableListener)? { get set }
    func render(_ state: LoggedOutViewState)
}

@MainActor public protocol LoggedOutViewControllable: ViewControllable {}
@MainActor @JS public protocol LoggedOutViewContract: LoggedOutPresentable, LoggedOutViewControllable {}

@MainActor
@JS public protocol LoginViewFactory: AnyObject {
    func makeLoggedOutView() -> any LoggedOutViewContract
}

@MainActor
@JS public final class LoggedOutDriver: LoggedOutPresentableListener {
    private let view: any LoggedOutViewContract
    @JS public private(set) var lastName: String = ""

    @JS public init(factory: any LoginViewFactory) {
        self.view = factory.makeLoggedOutView()
    }

    @JS public func activate() {
        view.listener = self
        view.render(LoggedOutViewState(errorMessage: nil, isLoading: false))
    }

    @JS public func handle(_ action: LoggedOutViewAction) {
        switch action {
        case .loginTapped(let rawName):
            lastName = rawName
            view.render(LoggedOutViewState(errorMessage: rawName.isEmpty ? "이름을 입력하세요" : nil, isLoading: !rawName.isEmpty))
        }
    }
}
