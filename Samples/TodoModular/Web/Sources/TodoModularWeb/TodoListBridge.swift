import JavaScriptKit

/// 목록 한 줄. `TodoCore.Todo`는 다른 패키지에 있어 `@JS`를 붙일 수 없으므로 경계용 값 타입을 따로 둔다.
/// Wasm의 `Int`는 32비트다. 범위를 넘는 id는 변환할 때 멈춘다.
@JS struct TodoListRow {
    let id: Int
    let title: String
    let isDone: Bool
}

/// 웹 뷰가 구현한다. 이 샘플은 `features/todo-list/view.tsx`가 구현한다.
@JS protocol TodoListViewBridge {
    func mount(host: JSObject, handle: TodoListScreenHandle)
    func render(rows: [TodoListRow])
}

@JS final class TodoListScreenHandle: Sendable {
    private let onTodoTapped: @MainActor @Sendable (Int) -> Void

    init(onTodoTapped: @escaping @MainActor @Sendable (Int) -> Void) {
        self.onTodoTapped = onTodoTapped
    }

    @JS func todoTapped(id: Int) {
        MainActor.assumeIsolated { onTodoTapped(id) }
    }
}
