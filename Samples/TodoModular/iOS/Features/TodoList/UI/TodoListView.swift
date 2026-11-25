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
    let isLoading: Bool
    let errorMessage: String?
    let onSelect: (Int64) -> Void
    let onRetry: () -> Void

    public init(
        items: [TodoListItem],
        isLoading: Bool = false,
        errorMessage: String? = nil,
        onSelect: @escaping (Int64) -> Void,
        onRetry: @escaping () -> Void = {}
    ) {
        self.items = items
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.onSelect = onSelect
        self.onRetry = onRetry
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isLoading {
                ProgressView().accessibilityIdentifier("todoLoadingIndicator")
            }
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).accessibilityIdentifier("todoErrorLabel")
                Button("다시 시도", action: onRetry)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("todoRetryButton")
            }
            ForEach(items) { item in
                Button((item.isDone ? "✓ " : "") + item.title) { onSelect(item.id) }
                    .accessibilityIdentifier("todoRow-\(item.id)")
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

#Preview("불러오기 실패") {
    TodoListView(items: [], errorMessage: "할 일을 불러오지 못했습니다", onSelect: { _ in })
}
