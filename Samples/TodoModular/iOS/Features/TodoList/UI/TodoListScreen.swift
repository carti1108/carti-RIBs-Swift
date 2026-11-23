import FeatureTodoListInterface
import Observation
import RIBs
import RIBsSwiftUI
import SwiftUI
import TodoCore

/// 할 일 목록 피처의 SwiftUI 뷰를 만든다.
@MainActor
public final class TodoListScreenFactory: TodoListViewFactory {
    public init() {}

    public func makeTodoListView() -> any TodoListViewContract { TodoListScreen() }
}

@MainActor
final class TodoListScreen: TodoListViewContract, SwiftUIRenderable {
    weak var listener: (any TodoListPresentableListener)?
    private let model = TodoListModel()

    func showTodos(_ todos: [Todo]) { model.todos = todos }

    func makeView() -> AnyView {
        AnyView(TodoListView(model: model) { [weak self] id in self?.listener?.didTapTodo(id: id) })
    }
}

@MainActor @Observable
final class TodoListModel {
    var todos: [Todo] = []
}

private struct TodoListView: View {
    let model: TodoListModel
    let onSelect: (Int64) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(model.todos) { todo in
                Button((todo.isDone ? "✓ " : "") + todo.title) { onSelect(todo.id) }
                    .accessibilityIdentifier("todoRow-\(todo.id)")
            }
        }
    }
}
