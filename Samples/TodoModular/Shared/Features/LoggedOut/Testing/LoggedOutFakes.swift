import FeatureLoggedOutInterface
import RIBs
import TodoCoreTesting

@MainActor
public final class FakeLoggedOutView: LoggedOutViewContract {
    public weak var listener: (any LoggedOutPresentableListener)?
    public private(set) var error: String?
    public private(set) var isLoading = false

    public init() {}

    public func showError(_ message: String?) { error = message }
    public func showLoading(_ isLoading: Bool) { self.isLoading = isLoading }
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
