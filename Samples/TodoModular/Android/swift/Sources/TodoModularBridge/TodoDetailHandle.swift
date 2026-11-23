import FeatureTodoDetailAndroid

/// Kotlin(Compose) 뷰가 구현한다. Kotlin `:feature:tododetail:ui`가 짝이다.
public protocol TodoDetailViewBridge {
    func render(title: String, isDone: Bool)
}

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
        MainActor.assumeIsolated { screen?.tapToggleDone() }
    }

    public func backTapped() {
        MainActor.assumeIsolated { screen?.tapBack() }
    }

    @MainActor private var screen: TodoDetailAndroidScreen? {
        controller?.screen(id: screenID, as: TodoDetailAndroidScreen.self)
    }
}
