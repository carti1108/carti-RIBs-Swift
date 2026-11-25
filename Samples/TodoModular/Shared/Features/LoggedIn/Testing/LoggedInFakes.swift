import FeatureLoggedInInterface
import FeatureTodoDetailInterface
import FeatureTodoListInterface
import RIBs
import TodoCore
import TodoCoreTesting

@MainActor
public final class FakeLoggedInView: LoggedInViewContract {
    public weak var listener: (any LoggedInPresentableListener)?
    public private(set) var states: [LoggedInViewState] = []
    public var state: LoggedInViewState? { states.last }
    public enum Call: Equatable, Sendable { case showList, showDetail, hideDetail }
    public private(set) var calls: [Call] = []
    public private(set) var list: (any ViewControllable)?
    public private(set) var detail: (any ViewControllable)?
    /// 맨 위에 보이는 화면. 상세가 있으면 상세, 없으면 목록.
    public var screen: (any ViewControllable)? { detail ?? list }

    public init() {}

    public func render(_ state: LoggedInViewState) { states.append(state) }

    public func showList(_ screen: any ViewControllable) {
        calls.append(.showList)
        list = screen
    }

    public func showDetail(_ screen: any ViewControllable) {
        calls.append(.showDetail)
        detail = screen
    }

    public func hideDetail(_ screen: any ViewControllable) {
        calls.append(.hideDetail)
        if detail === screen { detail = nil }
    }

    /// 사용자가 제스처로 상세를 닫은 상황. 플랫폼 뷰처럼 화면을 먼저 빼고 알린다.
    public func dismissDetailByUser() {
        detail = nil
        listener?.handle(.detailDismissedByUser)
    }
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
    public let todoRepository: any TodoRepository
    private let listBuilder: any TodoListBuildable
    private let detailBuilder: any TodoDetailBuildable
    public private(set) var listDependencies: [any TodoListDependency] = []
    public private(set) var detailDependencies: [any TodoDetailDependency] = []

    public init(
        clock: any TodoClock,
        listBuilder: any TodoListBuildable,
        detailBuilder: any TodoDetailBuildable,
        todoRepository: any TodoRepository = FakeTodoRepository()
    ) {
        self.clock = clock
        self.todoRepository = todoRepository
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
