import FeatureTodoListInterface
import RIBs
import TodoCore
import TodoCoreTesting

@MainActor
public final class FakeTodoListView: TodoListViewContract {
    public weak var listener: (any TodoListPresentableListener)?
    public private(set) var states: [TodoListViewState] = []
    public var state: TodoListViewState? { states.last }

    public init() {}

    public func render(_ state: TodoListViewState) { states.append(state) }
}

@MainActor
public final class FakeTodoListViewFactory: TodoListViewFactory {
    public private(set) var views: [FakeTodoListView] = []

    public init() {}

    public func makeTodoListView() -> any TodoListViewContract {
        let view = FakeTodoListView()
        views.append(view)
        return view
    }
}

@MainActor
public final class FakeTodoListListener: TodoListListener {
    public private(set) var selectedIDs: [Int64] = []
    public private(set) var signInRequests = 0

    public init() {}

    public func didSelectTodo(id: Int64) { selectedIDs.append(id) }
    public func didRequireSignIn() { signInRequests += 1 }
}

@MainActor
public final class FakeTodoListDependency: TodoListDependency {
    public let todoStore: TodoStore
    public let todoRepository: any TodoRepository

    public init(todoStore: TodoStore = TodoStore(), todoRepository: any TodoRepository = FakeTodoRepository()) {
        self.todoStore = todoStore
        self.todoRepository = todoRepository
    }
}

/// 부모 피처 테스트용. 빈 화면 Router를 돌려주고, 받은 리스너를 기록한다.
@MainActor
public final class FakeTodoListBuildable: TodoListBuildable {
    public private(set) var listeners: [any TodoListListener] = []
    public private(set) var views: [FakeTodoListView] = []

    public init() {}

    public func build(listener: any TodoListListener) -> any ViewableRouting {
        listeners.append(listener)
        let view = FakeTodoListView()
        views.append(view)
        return StubRouter(interactor: Interactor(), viewController: view)
    }
}
