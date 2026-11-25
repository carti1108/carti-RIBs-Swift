import JavaScriptKit

/// 웹 뷰가 구현한다. 이 샘플은 `features/todo-detail/view.tsx`가 구현한다.
@JS protocol TodoDetailViewBridge {
    func mount(host: JSObject, handle: TodoDetailScreenHandle)
    func render(title: String, isDone: Bool)
}

@JS final class TodoDetailScreenHandle: Sendable {
    private let onToggleDoneTapped: @MainActor @Sendable () -> Void
    private let onBackTapped: @MainActor @Sendable () -> Void

    init(
        onToggleDoneTapped: @escaping @MainActor @Sendable () -> Void,
        onBackTapped: @escaping @MainActor @Sendable () -> Void
    ) {
        self.onToggleDoneTapped = onToggleDoneTapped
        self.onBackTapped = onBackTapped
    }

    @JS func toggleDoneTapped() {
        MainActor.assumeIsolated { onToggleDoneTapped() }
    }

    @JS func backTapped() {
        MainActor.assumeIsolated { onBackTapped() }
    }
}
