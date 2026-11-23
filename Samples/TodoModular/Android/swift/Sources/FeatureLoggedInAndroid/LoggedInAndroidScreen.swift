import FeatureLoggedInInterface
import RIBs
import RIBsAndroid
import TodoAndroidSupport

/// 로그인 피처의 Android 화면을 만든다. 자식 화면은 화면 트리의 `child`로만 내보내 자식 피처를 모른다.
@MainActor
public final class LoggedInAndroidViewFactory: LoggedInViewFactory {
    nonisolated public static let kind = "loggedIn"
    private let context: ScreenContext

    public init(context: ScreenContext) {
        self.context = context
    }

    public func makeLoggedInView() -> any LoggedInViewContract { LoggedInAndroidScreen(context: context) }
}

public struct LoggedInScreenState: Equatable, Sendable {
    public var userName = ""
    public var sessionSeconds: Int64 = 0
}

@MainActor
public final class LoggedInAndroidScreen: BridgedScreen<LoggedInScreenState>, LoggedInViewContract {
    public weak var listener: (any LoggedInPresentableListener)?
    private lazy var slot = AndroidScreenSlot(owner: self)

    init(context: ScreenContext) {
        super.init(kind: LoggedInAndroidViewFactory.kind, context: context, initialState: LoggedInScreenState())
    }

    public func showUserName(_ name: String) {
        var state = currentState
        state.userName = name
        setViewState(state)
    }

    public func showSessionSeconds(_ seconds: Int64) {
        var state = currentState
        state.sessionSeconds = seconds
        setViewState(state)
    }

    public func showScreen(_ screen: any ViewControllable) { slot.show(screen) }
    public func hideScreen(_ screen: any ViewControllable) { slot.hide(screen) }

    public func tapLogout() { listener?.didTapLogout() }

    override public func state() -> [String: RibValue] { ["child": slot.renderedValue] }
}
