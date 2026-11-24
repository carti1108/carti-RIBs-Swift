import SwiftUI

// 순수 뷰(ADR-0027). 값과 콜백만 받아 그린다. SwiftUI만 import하고 공유 코드(`LoginShared`)와 RIBs를 모른다.

/// 목록 한 줄. 뷰가 정의하고 어댑터가 채운다.
struct TodoListItem: Identifiable, Equatable {
    let id: Int64
    let title: String
    let isDone: Bool
}

struct TodoListView: View {
    let items: [TodoListItem]
    let onSelect: (Int64) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items) { item in
                Button((item.isDone ? "✓ " : "") + item.title) { onSelect(item.id) }
                    .accessibilityIdentifier("todoRow-\(item.id)")
            }
        }
    }
}

#Preview {
    TodoListView(
        items: [
            TodoListItem(id: 1, title: "우유 사기", isDone: true),
            TodoListItem(id: 2, title: "RIB 문서 읽기", isDone: false),
        ],
        onSelect: { _ in }
    )
}
