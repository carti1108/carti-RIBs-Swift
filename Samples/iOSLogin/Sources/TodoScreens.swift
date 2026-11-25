import LoginShared
import RIBs
import RIBsSwiftUI
import SwiftUI

/// 할 일 목록 RIB의 어댑터(ADR-0027). 공유 코드의 `Todo`를 순수 뷰의 `TodoListItem`으로 옮긴다.
@MainActor
final class TodoListScreen: TodoListViewContract, SwiftUIRenderable {
    weak var listener: (any TodoListPresentableListener)?
    let model = TodoListModel()

    func render(_ state: TodoListViewState) { model.state = state }

    func makeView() -> AnyView {
        AnyView(TodoListContent(model: model) { [weak self] action in self?.listener?.handle(action) })
    }
}

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

/// 할 일 상세 RIB의 어댑터. 뒤로 버튼은 공유 코드에 닫기를 요청하고, 닫는 일은 부모 RIB이 한다.
@MainActor
final class TodoDetailScreen: TodoDetailViewContract, SwiftUIRenderable {
    weak var listener: (any TodoDetailPresentableListener)?
    let model = TodoDetailModel()

    func render(_ state: TodoDetailViewState) { model.state = state }

    func makeView() -> AnyView {
        AnyView(TodoDetailContent(model: model) { [weak self] action in self?.listener?.handle(action) })
    }
}

private struct TodoDetailContent: View {
    let model: TodoDetailModel
    let send: (TodoDetailViewAction) -> Void

    var body: some View {
        TodoDetailView(
            title: model.state.title,
            isDone: model.state.isDone,
            onBack: { send(.backTapped) },
            onToggleDone: { send(.toggleDoneTapped) }
        )
    }
}
