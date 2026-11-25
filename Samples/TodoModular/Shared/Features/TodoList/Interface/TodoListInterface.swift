import RIBs
import TodoCore

public struct TodoListViewState: Equatable, Sendable {
    public var todos: [Todo]
    /// 목록을 불러오는 중이다.
    public var isLoading: Bool
    /// 불러오지 못했을 때 보여 줄 문구. 있으면 뷰는 다시 시도 버튼을 함께 보여 준다.
    public var errorMessage: String?

    public init(todos: [Todo] = [], isLoading: Bool = false, errorMessage: String? = nil) {
        self.todos = todos
        self.isLoading = isLoading
        self.errorMessage = errorMessage
    }
}

public enum TodoListViewAction: Equatable, Sendable {
    case todoTapped(id: Int64)
    case retryTapped
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
    var todoRepository: any TodoRepository { get }
}

@MainActor
public protocol TodoListListener: AnyObject {
    func didSelectTodo(id: Int64)
}

@MainActor
public protocol TodoListBuildable: Buildable {
    func build(listener: any TodoListListener) -> any ViewableRouting
}
