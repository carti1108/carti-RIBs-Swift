import RIBs
import TodoCore

public struct TodoListViewState: Equatable, Sendable {
    public var todos: [Todo]

    public init(todos: [Todo] = []) {
        self.todos = todos
    }
}

public enum TodoListViewAction: Equatable, Sendable {
    case todoTapped(id: Int64)
}

@MainActor
public protocol TodoListPresentableListener: AnyObject {
    func handle(_ action: TodoListViewAction)
}

@MainActor
public protocol TodoListPresentable: Presentable {
    var listener: (any TodoListPresentableListener)? { get set }
    func render(_ state: TodoListViewState)
}

@MainActor
public protocol TodoListViewControllable: ViewControllable {}

@MainActor
public protocol TodoListViewContract: TodoListPresentable, TodoListViewControllable {}

@MainActor
public protocol TodoListViewFactory: AnyObject {
    func makeTodoListView() -> any TodoListViewContract
}

@MainActor
public protocol TodoListDependency: Dependency {
    var todoStore: TodoStore { get }
}

@MainActor
public protocol TodoListListener: AnyObject {
    func didSelectTodo(id: Int64)
}

@MainActor
public protocol TodoListBuildable: Buildable {
    func build(listener: any TodoListListener) -> any ViewableRouting
}
