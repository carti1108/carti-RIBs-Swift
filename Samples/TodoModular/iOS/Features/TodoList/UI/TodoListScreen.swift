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

    func render(_ state: TodoListViewState) { model.state = state }

    func makeView() -> AnyView {
        AnyView(TodoListView(model: model) { [weak self] action in self?.listener?.handle(action) })
    }
}

@MainActor @Observable
final class TodoListModel {
    var state = TodoListViewState()
}

private struct TodoListView: View {
    let model: TodoListModel
    let send: (TodoListViewAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(model.state.todos) { todo in
                Button((todo.isDone ? "✓ " : "") + todo.title) { send(.todoTapped(id: todo.id)) }
                    .accessibilityIdentifier("todoRow-\(todo.id)")
            }
        }
    }
}
