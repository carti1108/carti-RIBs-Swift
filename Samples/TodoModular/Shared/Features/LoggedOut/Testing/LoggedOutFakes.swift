import FeatureLoggedOutInterface
import RIBs
import TodoCoreTesting

@MainActor
public final class FakeLoggedOutView: LoggedOutViewContract {
    public weak var listener: (any LoggedOutPresentableListener)?
    /// 그려진 상태를 순서대로 모은다.
    public private(set) var states: [LoggedOutViewState] = []
    public var state: LoggedOutViewState? { states.last }

    public init() {}

    public func render(_ state: LoggedOutViewState) { states.append(state) }
}

@MainActor
public final class FakeLoggedOutViewFactory: LoggedOutViewFactory {
    public private(set) var views: [FakeLoggedOutView] = []

    public init() {}

    public func makeLoggedOutView() -> any LoggedOutViewContract {
        let view = FakeLoggedOutView()
        views.append(view)
        return view
    }
}

@MainActor
public final class FakeLoggedOutListener: LoggedOutListener {
    public private(set) var loggedInNames: [String] = []

    public init() {}

    public func didLogin(userName: String) { loggedInNames.append(userName) }
}

/// 부모 피처 테스트용. 실제 로직 없이 빈 화면 Router를 돌려준다.
@MainActor
public final class FakeLoggedOutBuildable: LoggedOutBuildable {
    public private(set) var listeners: [any LoggedOutListener] = []
    public private(set) var views: [FakeLoggedOutView] = []

    public init() {}

    public func build(listener: any LoggedOutListener) -> any ViewableRouting {
        listeners.append(listener)
        let view = FakeLoggedOutView()
        views.append(view)
        return StubRouter(interactor: Interactor(), viewController: view)
    }
}
