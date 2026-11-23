import FeatureTodoListInterface
import JavaScriptKit
import RIBs
import TodoWebSupport

/// 할 일 목록 피처의 웹 화면을 만든다. 화면을 그리는 JS 뷰는 조립 쪽이 `mount`에서 붙인다.
@MainActor
public final class TodoListWebViewFactory: TodoListViewFactory {
    private let mount: @MainActor (TodoListWebScreen) -> Void

    public init(mount: @escaping @MainActor (TodoListWebScreen) -> Void) {
        self.mount = mount
    }

    public func makeTodoListView() -> any TodoListViewContract {
        let screen = TodoListWebScreen()
        mount(screen)
        return screen
    }
}

@MainActor
public final class TodoListWebScreen: WebScreen<TodoListViewState>, TodoListViewContract {
    public weak var listener: (any TodoListPresentableListener)?

    init() {
        super.init(tag: "ul", id: "todoList", initialState: TodoListViewState())
    }

    public func render(_ state: TodoListViewState) { setViewState(state) }

    public func send(_ action: TodoListViewAction) { listener?.handle(action) }
}
