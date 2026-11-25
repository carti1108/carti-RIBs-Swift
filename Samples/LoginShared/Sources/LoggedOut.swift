import RIBs

/// 화면에 그릴 값 전체. 플랫폼은 이 값만 보고 그린다.
///
/// 샘플의 뷰 계약은 모두 `ViewState`/`ViewAction` 모양이다(ADR-0025). 라이브러리는 이 패턴을 요구하지 않는다(ADR-0019).
/// 상태를 한 값으로 넘기면 에러와 로딩이 한 번에 바뀌어 중간 상태가 화면에 나오지 않는다.
public struct LoggedOutViewState: Equatable, Sendable {
    public var errorMessage: String?
    public var isLoading: Bool

    public init(errorMessage: String? = nil, isLoading: Bool = false) {
        self.errorMessage = errorMessage
        self.isLoading = isLoading
    }
}

/// 뷰 → 공유 코드: 사용자 입력.
public enum LoggedOutViewAction: Equatable, Sendable {
    case loginTapped(rawName: String)
}

@MainActor
public protocol LoggedOutPresentableListener: AnyObject {
    func handle(_ action: LoggedOutViewAction)
}

/// 공유 코드 → 뷰: 플랫폼이 구현하는 뷰 계약.
@MainActor
public protocol LoggedOutPresentable: Presentable {
    /// 활성 구간에만 설정된다. 비활성이면 nil이라 입력이 무시된다. 플랫폼은 `weak`로 둔다.
    var listener: (any LoggedOutPresentableListener)? { get set }
    func render(_ state: LoggedOutViewState)
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
    private var viewState = LoggedOutViewState()

    init(presenter: any LoggedOutPresentable, authService: any AuthService, listener: any LoggedOutListener) {
        self.authService = authService
        self.listener = listener
        super.init(presenter: presenter)
    }

    override func didBecomeActive() {
        presenter.listener = self
        presenter.render(viewState)
    }

    override func willResignActive() {
        presenter.listener = nil
        isLoggingIn = false
        // 요청이 취소됐으니 다시 붙을 때 로딩으로 그리지 않는다.
        viewState = LoggedOutViewState(errorMessage: viewState.errorMessage)
    }

    func handle(_ action: LoggedOutViewAction) {
        switch action {
        case .loginTapped(let rawName): didTapLogin(rawName: rawName)
        }
    }

    private func didTapLogin(rawName: String) {
        let name = Self.trimmed(rawName)
        guard !name.isEmpty else {
            update { $0.errorMessage = Self.emptyNameError }
            return
        }
        login(name)
    }

    /// 상태를 고치고 한 번만 그린다.
    private func update(_ change: (inout LoggedOutViewState) -> Void) {
        var next = viewState
        change(&next)
        guard next != viewState else { return }
        viewState = next
        presenter.render(next)
    }

    private func login(_ userName: String) {
        guard !isLoggingIn else { return }
        isLoggingIn = true
        startTask { [weak self] in
            guard let self else { return }
            update { $0 = LoggedOutViewState(errorMessage: nil, isLoading: true) }
            let result: AuthResult
            do {
                result = try await authService.signIn(userName: userName)
            } catch {
                return  // 비활성화로 취소됐다. 뷰는 이미 떨어졌다.
            }
            isLoggingIn = false
            switch result {
            case .success(let name):
                update { $0.isLoading = false }
                listener?.didLogin(userName: name)
            case .failure(let message):
                update { $0 = LoggedOutViewState(errorMessage: message, isLoading: false) }
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
