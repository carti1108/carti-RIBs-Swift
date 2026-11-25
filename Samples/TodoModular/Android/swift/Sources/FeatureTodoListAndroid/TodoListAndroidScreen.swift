import FeatureTodoListInterface
import RIBs
import TodoAndroidSupport

/// 할 일 목록 피처의 Android 화면을 만든다.
@MainActor
public final class TodoListAndroidViewFactory: TodoListViewFactory {
    nonisolated public static let kind = "todoList"
    private let context: ScreenContext

    public init(context: ScreenContext) {
        self.context = context
    }

    public func makeTodoListView() -> any TodoListViewContract { TodoListAndroidScreen(context: context) }
}

@MainActor
public final class TodoListAndroidScreen: BridgedScreen<TodoListViewState>, TodoListViewContract {
    public weak var listener: (any TodoListPresentableListener)?

    init(context: ScreenContext) {
        super.init(kind: TodoListAndroidViewFactory.kind, context: context, initialState: TodoListViewState())
    }

    public func render(_ state: TodoListViewState) { setViewState(state) }

    public func send(_ action: TodoListViewAction) { listener?.handle(action) }
}
