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

/// 이름 입력값은 Kotlin 화면이 들고 있다가 로그인 입력 때 인자로 넘긴다.
@MainActor
public final class LoggedOutAndroidScreen: BridgedScreen<LoggedOutViewState>, LoggedOutViewContract {
    public weak var listener: (any LoggedOutPresentableListener)?

    init(context: ScreenContext) {
        super.init(kind: LoggedOutAndroidViewFactory.kind, context: context, initialState: LoggedOutViewState())
    }

    public func render(_ state: LoggedOutViewState) { setViewState(state) }

    public func send(_ action: LoggedOutViewAction) { listener?.handle(action) }
}
