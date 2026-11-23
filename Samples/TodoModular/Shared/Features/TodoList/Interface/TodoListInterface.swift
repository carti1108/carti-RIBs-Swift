import RIBs
import TodoCore

@MainActor
public protocol TodoListPresentableListener: AnyObject {
    func didTapTodo(id: Int64)
}

@MainActor
public protocol TodoListPresentable: Presentable {
    var listener: (any TodoListPresentableListener)? { get set }
    func showTodos(_ todos: [Todo])
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
