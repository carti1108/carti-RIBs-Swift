import FeatureLoggedInAndroid

/// Kotlin(Compose) 뷰가 구현한다. 자식 화면은 이 통로가 아니라 화면 트리의 `child`로 받는다.
/// Kotlin `:feature:loggedin:ui`가 짝이다.
public protocol LoggedInViewBridge {
    func render(userName: String, sessionSeconds: Int64)
}

/// Kotlin 뷰가 화면 트리의 `id`로 만들어 쥔다. 그 id의 화면이 이미 내려갔으면 호출은 아무 일도 하지 않는다.
public final class LoggedInScreenHandle: Sendable {
    private let screenID: Int64

    public init(screenID: Int64) {
        self.screenID = screenID
    }

    public func attach(view: any LoggedInViewBridge) {
        nonisolated(unsafe) let view = view
        MainActor.assumeIsolated {
            screen?.attach { view.render(userName: $0.userName, sessionSeconds: $0.sessionSeconds) }
        }
    }

    public func detach() {
        MainActor.assumeIsolated { screen?.detach() }
    }

    public func logoutTapped() {
        MainActor.assumeIsolated { screen?.send(.logoutTapped) }
    }

    @MainActor private var screen: LoggedInAndroidScreen? {
        controller?.screen(id: screenID, as: LoggedInAndroidScreen.self)
    }
}
