import LoginShared
import RIBs
import RIBsSwiftUI
import SwiftUI

/// 할 일 목록 RIB의 뷰.
@MainActor
final class TodoListScreen: TodoListViewContract, SwiftUIRenderable {
    weak var listener: (any TodoListPresentableListener)?
    let model = TodoListModel()

    func render(_ state: TodoListViewState) { model.state = state }

    func makeView() -> AnyView {
        AnyView(TodoListView(model: model) { [weak self] id in self?.listener?.handle(.todoTapped(id: id)) })
    }
}

private struct TodoListView: View {
    let model: TodoListModel
    let onSelect: (Int64) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(model.state.todos) { todo in
                Button((todo.isDone ? "✓ " : "") + todo.title) { onSelect(todo.id) }
                    .accessibilityIdentifier("todoRow-\(todo.id)")
            }
        }
    }
}

/// 할 일 상세 RIB의 뷰. 뒤로 버튼은 공유 코드에 닫기를 요청하고, 닫는 일은 부모 RIB이 한다.
@MainActor
final class TodoDetailScreen: TodoDetailViewContract, SwiftUIRenderable {
    weak var listener: (any TodoDetailPresentableListener)?
    let model = TodoDetailModel()

    func render(_ state: TodoDetailViewState) { model.state = state }

    func makeView() -> AnyView {
        AnyView(TodoDetailView(
            model: model,
            onBack: { [weak self] in self?.listener?.handle(.backTapped) },
            onToggle: { [weak self] in self?.listener?.handle(.toggleDoneTapped) }
        ))
    }
}

private struct TodoDetailView: View {
    let model: TodoDetailModel
    let onBack: () -> Void
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("← 목록", action: onBack).accessibilityIdentifier("backButton")
            Text(model.state.title).font(.title3.bold()).accessibilityIdentifier("detailTitle")
            Button(model.state.isDone ? "완료 취소" : "완료로 표시", action: onToggle)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("toggleDoneButton")
        }
    }
}
