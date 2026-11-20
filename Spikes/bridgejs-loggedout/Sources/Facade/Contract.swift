// carti-RIBs-Swift 의 뷰 계약 그대로. @JS 를 붙이지 않고 internal 로 둔다.
@MainActor protocol Presentable: AnyObject {}
@MainActor protocol ViewControllable: AnyObject {}

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

@MainActor
final class LoggedOutDriver: LoggedOutPresentableListener {
    private let view: any LoggedOutViewContract
    private(set) var lastName: String = ""

    init(factory: any LoginViewFactory) { self.view = factory.makeLoggedOutView() }

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
