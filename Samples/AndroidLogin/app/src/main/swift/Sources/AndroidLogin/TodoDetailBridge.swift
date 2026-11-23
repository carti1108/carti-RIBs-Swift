import AndroidLoginUI

/// Kotlin(Compose) 뷰가 구현한다.
public protocol TodoDetailViewBridge {
    func render(title: String, isDone: Bool)
}

/// Kotlin 뷰가 화면 트리의 `id`로 만들어 쥔다. 그 id의 TodoDetail 화면이 이미 내려갔으면 호출은 아무 일도 하지 않는다.
public final class TodoDetailScreenHandle: Sendable {
    private let screenID: Int64

    public init(screenID: Int64) {
        self.screenID = screenID
    }

    public func attach(view: any TodoDetailViewBridge) {
        nonisolated(unsafe) let view = view
        MainActor.assumeIsolated {
            screen?.attach { view.render(title: $0.title, isDone: $0.isDone) }
        }
    }

    public func detach() {
        MainActor.assumeIsolated { screen?.detach() }
    }

    public func toggleDoneTapped() {
        MainActor.assumeIsolated { screen?.send(.toggleDoneTapped) }
    }

    public func backTapped() {
        MainActor.assumeIsolated { screen?.send(.backTapped) }
    }

    @MainActor private var screen: TodoDetailScreen? {
        controller?.screen(id: screenID, as: TodoDetailScreen.self)
    }
}
