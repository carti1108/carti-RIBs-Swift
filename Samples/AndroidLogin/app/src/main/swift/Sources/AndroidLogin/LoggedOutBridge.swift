import AndroidLoginUI
import LoginShared

// swift-java가 Java로 내보내는 층. 격리 없는 public 타입만 두고 `@MainActor` 뷰 계약은 감춘다.
// 모든 호출은 Android 메인 스레드에서 온다고 가정하고 `MainActor.assumeIsolated`로 확인한다(`JNI.swift`와 같다).

/// Kotlin(Compose) 뷰가 구현한다.
public protocol LoggedOutViewBridge {
    func render(errorMessage: String?, isLoading: Bool)
}

/// Kotlin 뷰가 화면 트리의 `id`로 만들어 쥐고, 뷰를 붙이고 입력을 보낸다.
/// 그 id의 LoggedOut 화면이 이미 내려갔으면 모든 호출은 아무 일도 하지 않는다.
public final class LoggedOutScreenHandle: Sendable {
    private let screenID: Int64

    public init(screenID: Int64) {
        self.screenID = screenID
    }

    public func attach(view: any LoggedOutViewBridge) {
        nonisolated(unsafe) let view = view
        MainActor.assumeIsolated {
            screen?.attach { view.render(errorMessage: $0.errorMessage, isLoading: $0.isLoading) }
        }
    }

    public func detach() {
        MainActor.assumeIsolated { screen?.detach() }
    }

    public func loginTapped(rawName: String) {
        MainActor.assumeIsolated { screen?.send(.loginTapped(rawName: rawName)) }
    }

    @MainActor private var screen: LoggedOutScreen? {
        controller?.screen(id: screenID, as: LoggedOutScreen.self)
    }
}
