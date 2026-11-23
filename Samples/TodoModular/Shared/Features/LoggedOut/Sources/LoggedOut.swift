import FeatureLoggedOutInterface
import RIBs
import TodoCore

public final class LoggedOutBuilder: Builder<any LoggedOutDependency>, LoggedOutBuildable {
    private let viewFactory: any LoggedOutViewFactory

    public init(dependency: any LoggedOutDependency, viewFactory: any LoggedOutViewFactory) {
        self.viewFactory = viewFactory
        super.init(dependency: dependency)
    }

    public func build(listener: any LoggedOutListener) -> any ViewableRouting {
        let view = viewFactory.makeLoggedOutView()
        let interactor = LoggedOutInteractor(presenter: view, authService: dependency.authService, listener: listener)
        return LoggedOutRouter(interactor: interactor, viewController: view)
    }
}

/// 뷰 입력을 로그인 의도로 해석하고, 로그인 요청을 활성 구간 Task에서 실행한다. 비활성화되면 요청이 취소된다.
final class LoggedOutInteractor: PresentableInteractor<any LoggedOutPresentable>, LoggedOutPresentableListener {
    static let emptyNameError = "이름을 입력하세요"

    private let authService: any AuthService
    private weak var listener: (any LoggedOutListener)?
    private var isLoggingIn = false

    init(presenter: any LoggedOutPresentable, authService: any AuthService, listener: any LoggedOutListener) {
        self.authService = authService
        self.listener = listener
        super.init(presenter: presenter)
    }

    override func didBecomeActive() {
        presenter.listener = self
    }

    override func willResignActive() {
        presenter.listener = nil
        isLoggingIn = false
    }

    func didTapLogin(rawName: String) {
        let name = Self.trimmed(rawName)
        guard !name.isEmpty else {
            presenter.showError(Self.emptyNameError)
            return
        }
        presenter.showError(nil)
        login(name)
    }

    private func login(_ userName: String) {
        guard !isLoggingIn else { return }
        isLoggingIn = true
        startTask { [weak self] in
            guard let self else { return }
            presenter.showLoading(true)
            let result: AuthResult
            do {
                result = try await authService.signIn(userName: userName)
            } catch {
                return  // 비활성화로 취소됐다. 뷰는 이미 떨어졌다.
            }
            isLoggingIn = false
            presenter.showLoading(false)
            switch result {
            case .success(let name): listener?.didLogin(userName: name)
            case .failure(let message): presenter.showError(message)
            }
        }
    }

    /// Foundation 없이 앞뒤 공백을 지운다.
    private static func trimmed(_ text: String) -> String {
        guard let start = text.firstIndex(where: { !$0.isWhitespace }),
              let end = text.lastIndex(where: { !$0.isWhitespace })
        else { return "" }
        return String(text[start...end])
    }
}

typealias LoggedOutRouter = ViewableRouter<LoggedOutInteractor, any LoggedOutViewControllable>
