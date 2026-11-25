import FeatureTodoListInterface
import FeatureTodoListUI
import Observation
import RIBs
import RIBsSwiftUI
import SwiftUI
import TodoCore

/// 할 일 목록 피처의 어댑터(ADR-0027)를 만든다.
@MainActor
public final class TodoListScreenFactory: TodoListViewFactory {
    public init() {}

    public func makeTodoListView() -> any TodoListViewContract { TodoListScreen() }
}

/// 뷰 계약을 구현하고, 받은 상태를 풀어 순수 뷰(`FeatureTodoListUI`)에 넘긴다.
@MainActor
final class TodoListScreen: TodoListViewContract, SwiftUIRenderable {
    weak var listener: (any TodoListPresentableListener)?
    private let model = TodoListModel()

    func render(_ state: TodoListViewState) { model.state = state }

    func makeView() -> AnyView {
        AnyView(TodoListContent(model: model) { [weak self] action in self?.listener?.handle(action) })
    }
}

@MainActor @Observable
final class TodoListModel {
    var state = TodoListViewState()
}

/// 모델을 관찰해 순수 뷰를 다시 그린다. 상태를 인자로 풀고 콜백을 액션으로 묶는다.
private struct TodoListContent: View {
    let model: TodoListModel
    let send: (TodoListViewAction) -> Void

    var body: some View {
        TodoListView(
            items: model.state.todos.map { TodoListItem(id: $0.id, title: $0.title, isDone: $0.isDone) },
            onSelect: { send(.todoTapped(id: $0)) }
        )
    }
}
