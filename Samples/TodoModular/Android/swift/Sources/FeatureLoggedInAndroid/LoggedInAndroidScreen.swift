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

@MainActor
public final class LoggedInAndroidScreen: BridgedScreen<LoggedInViewState>, LoggedInViewContract {
    public weak var listener: (any LoggedInPresentableListener)?
    private lazy var list = AndroidScreenSlot(owner: self)
    private lazy var detail = AndroidScreenSlot(owner: self)

    init(context: ScreenContext) {
        super.init(kind: LoggedInAndroidViewFactory.kind, context: context, initialState: LoggedInViewState(userName: ""))
    }

    public func render(_ state: LoggedInViewState) { setViewState(state) }

    public func showList(_ screen: any ViewControllable) { list.show(screen) }
    public func showDetail(_ screen: any ViewControllable) { detail.show(screen) }
    public func hideDetail(_ screen: any ViewControllable) { detail.hide(screen) }

    public func send(_ action: LoggedInViewAction) { listener?.handle(action) }

    /// `child`는 맨 위 화면이다. 상세가 있으면 상세, 없으면 목록.
    /// 시스템 뒤로 가기는 `handleBackPress`로 공유 코드를 거치므로 Kotlin 쪽에 화면을 직접 닫는 경로가 없다.
    override public func state() -> [String: RibValue] {
        ["child": detail.current == nil ? list.renderedValue : detail.renderedValue]
    }
}
