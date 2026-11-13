import RIBs

/// 뷰 → 공유 코드: 사용자 입력.
@MainActor
public protocol LoggedOutPresentableListener: AnyObject {
    func didTapLogin(rawName: String)
}

/// 공유 코드 → 뷰: 플랫폼이 구현하는 뷰 계약.
@MainActor
public protocol LoggedOutPresentable: Presentable {
    /// 활성 구간에만 설정된다. 비활성이면 nil이라 입력이 무시된다. 플랫폼은 `weak`로 둔다.
    var listener: (any LoggedOutPresentableListener)? { get set }
    func showError(_ message: String?)
    func showLoading(_ isLoading: Bool)
}

/// Router → 뷰. 붙일 자식 화면이 없어 비어 있다.
@MainActor
public protocol LoggedOutViewControllable: ViewControllable {}

/// 플랫폼 뷰 하나가 구현하는 묶음. Interactor는 `LoggedOutPresentable`로, Router는 `LoggedOutViewControllable`로만 본다.
@MainActor
public protocol LoggedOutViewContract: LoggedOutPresentable, LoggedOutViewControllable {}

@MainActor
protocol LoggedOutDependency: Dependency {
    var viewFactory: any LoginViewFactory { get }
    var authService: any AuthService { get }
}

/// 자식 → 부모: 사용자 의도로 표현한다. 라우팅은 부모가 정한다.
@MainActor
protocol LoggedOutListener: AnyObject {
    func didLogin(userName: String)
}

final class LoggedOutBuilder: Builder<any LoggedOutDependency> {
    func build(listener: any LoggedOutListener) -> LoggedOutRouter {
        let view = dependency.viewFactory.makeLoggedOutView()
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
        let isSpace: (Character) -> Bool = { $0.isWhitespace }
        guard let start = text.firstIndex(where: { !isSpace($0) }),
              let end = text.lastIndex(where: { !isSpace($0) })
        else { return "" }
        return String(text[start...end])
    }
}

typealias LoggedOutRouter = ViewableRouter<LoggedOutInteractor, any LoggedOutViewControllable>
