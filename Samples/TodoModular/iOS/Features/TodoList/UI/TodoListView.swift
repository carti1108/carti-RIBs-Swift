import SwiftUI

// 순수 뷰(ADR-0027). 값과 콜백만 받아 그린다. 이 타깃(`FeatureTodoListUI`)은 SwiftUI에만 의존하고 공유 패키지와 RIBs를 모른다.

/// 목록 한 줄. 뷰가 정의하고 어댑터가 채운다.
public struct TodoListItem: Identifiable, Equatable {
    public let id: Int64
    public let title: String
    public let isDone: Bool

    public init(id: Int64, title: String, isDone: Bool) {
        self.id = id
        self.title = title
        self.isDone = isDone
    }
}

public struct TodoListView: View {
    let items: [TodoListItem]
    let onSelect: (Int64) -> Void

    public init(items: [TodoListItem], onSelect: @escaping (Int64) -> Void) {
        self.items = items
        self.onSelect = onSelect
    }

    public var body: some View {
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
