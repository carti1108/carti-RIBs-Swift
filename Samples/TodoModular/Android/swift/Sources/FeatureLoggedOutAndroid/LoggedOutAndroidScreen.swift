import FeatureLoggedOutInterface
import RIBs
import TodoAndroidSupport

/// 로그아웃 피처의 Android 화면을 만든다. Kotlin `:feature:loggedout:ui`가 짝이다.
@MainActor
public final class LoggedOutAndroidViewFactory: LoggedOutViewFactory {
    nonisolated public static let kind = "loggedOut"
    private let context: ScreenContext

    public init(context: ScreenContext) {
        self.context = context
    }

    public func makeLoggedOutView() -> any LoggedOutViewContract { LoggedOutAndroidScreen(context: context) }
}

public struct LoggedOutScreenState: Equatable, Sendable {
    public var errorMessage: String?
    public var isLoading = false
}

/// 이름 입력값은 Kotlin 화면이 들고 있다가 로그인 입력 때 인자로 넘긴다.
@MainActor
public final class LoggedOutAndroidScreen: BridgedScreen<LoggedOutScreenState>, LoggedOutViewContract {
    public weak var listener: (any LoggedOutPresentableListener)?

    init(context: ScreenContext) {
        super.init(kind: LoggedOutAndroidViewFactory.kind, context: context, initialState: LoggedOutScreenState())
    }

    public func showError(_ message: String?) {
        var state = currentState
        state.errorMessage = message
        setViewState(state)
    }

    public func showLoading(_ isLoading: Bool) {
        var state = currentState
        state.isLoading = isLoading
        setViewState(state)
    }

    public func tapLogin(rawName: String) { listener?.didTapLogin(rawName: rawName) }
}
