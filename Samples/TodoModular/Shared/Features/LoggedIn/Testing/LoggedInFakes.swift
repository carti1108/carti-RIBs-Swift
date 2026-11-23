import FeatureLoggedInInterface
import FeatureTodoDetailInterface
import FeatureTodoListInterface
import RIBs
import TodoCore
import TodoCoreTesting

@MainActor
public final class FakeLoggedInView: LoggedInViewContract {
    public weak var listener: (any LoggedInPresentableListener)?
    public private(set) var userName: String?
    public private(set) var sessionSeconds: Int64?
    public private(set) var screen: (any ViewControllable)?

    public init() {}

    public func showUserName(_ name: String) { userName = name }
    public func showSessionSeconds(_ seconds: Int64) { sessionSeconds = seconds }
    public func showScreen(_ screen: any ViewControllable) { self.screen = screen }
    public func hideScreen(_ screen: any ViewControllable) { if self.screen === screen { self.screen = nil } }
}

@MainActor
public final class FakeLoggedInViewFactory: LoggedInViewFactory {
    public private(set) var views: [FakeLoggedInView] = []

    public init() {}

    public func makeLoggedInView() -> any LoggedInViewContract {
        let view = FakeLoggedInView()
        views.append(view)
        return view
    }
}

@MainActor
public final class FakeLoggedInListener: LoggedInListener {
    public private(set) var logoutRequests = 0

    public init() {}

    public func didRequestLogout() { logoutRequests += 1 }
}

/// 자식 Builder를 테스트가 넣은 것으로 돌려주는 Dependency. 자식이 받은 Dependency도 기록한다.
@MainActor
public final class FakeLoggedInDependency: LoggedInDependency {
    public let clock: any TodoClock
    private let listBuilder: any TodoListBuildable
    private let detailBuilder: any TodoDetailBuildable
    public private(set) var listDependencies: [any TodoListDependency] = []
    public private(set) var detailDependencies: [any TodoDetailDependency] = []

    public init(clock: any TodoClock, listBuilder: any TodoListBuildable, detailBuilder: any TodoDetailBuildable) {
        self.clock = clock
        self.listBuilder = listBuilder
        self.detailBuilder = detailBuilder
    }

    public func makeTodoListBuilder(dependency: any TodoListDependency) -> any TodoListBuildable {
        listDependencies.append(dependency)
        return listBuilder
    }

    public func makeTodoDetailBuilder(dependency: any TodoDetailDependency) -> any TodoDetailBuildable {
        detailDependencies.append(dependency)
        return detailBuilder
    }
}
