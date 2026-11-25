import RIBs
import TodoCore

public struct TodoListViewState: Equatable, Sendable {
    public var todos: [Todo]
    /// 목록을 불러오는 중이다.
    public var isLoading: Bool
    /// 불러오지 못했을 때 보여 줄 문구. 있으면 뷰는 다시 시도 버튼을 함께 보여 준다.
    public var errorMessage: String?
    /// 방금 한 일의 결과 문구(예: 파일에서 할 일 추가). 없으면 뷰는 아무것도 보여 주지 않는다.
    public var notice: String?

    public init(todos: [Todo] = [], isLoading: Bool = false, errorMessage: String? = nil, notice: String? = nil) {
        self.todos = todos
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.notice = notice
    }
}

public enum TodoListViewAction: Equatable, Sendable {
    case todoTapped(id: Int64)
    case retryTapped
    /// 사용자가 끌어다 놓거나 고른 텍스트 파일. 파일을 받는 방법(끌어다 놓기, 선택 창)은 뷰가 다루고,
    /// 공유 코드는 이름과 내용만 받는다(#31). 내용의 각 줄이 할 일 하나다.
    case fileReceived(name: String, text: String)
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
