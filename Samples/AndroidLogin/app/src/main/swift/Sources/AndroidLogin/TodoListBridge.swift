import AndroidLoginUI
import LoginShared

/// 목록 한 줄. `LoginShared.Todo`는 루트 패키지에 있어 swift-java가 내보내지 못하므로 경계용 값 타입을 따로 둔다.
public struct TodoListRow: Sendable {
    public let id: Int64
    public let title: String
    public let isDone: Bool

    public init(id: Int64, title: String, isDone: Bool) {
        self.id = id
        self.title = title
        self.isDone = isDone
    }
}

/// Kotlin(Compose) 뷰가 구현한다.
///
/// 다른 화면과 달리 목록을 인자로 넘기지 않고, 바뀌었다고만 알린 뒤 뷰가 `TodoListScreenHandle.rows()`로 읽어 간다.
/// swift-java 0.7.0은 직접 만든 타입의 배열을 Java로 넘길 때 JNI `FindClass`로 원소 클래스를 찾는데,
/// Swift `Task`에서 시작한 호출에는 Java 호출 스택이 없어 앱 클래스 로더 대신 부트 클래스 로더가 쓰이고
/// `NoClassDefFoundError`로 앱이 멈춘다. Kotlin이 부른 호출의 반환값으로 넘기면 이 문제가 없다.
public protocol TodoListViewBridge {
    func rowsChanged()
}

/// Kotlin 뷰가 화면 트리의 `id`로 만들어 쥔다. 그 id의 TodoList 화면이 이미 내려갔으면 호출은 아무 일도 하지 않는다.
public final class TodoListScreenHandle: Sendable {
    private let screenID: Int64

    public init(screenID: Int64) {
        self.screenID = screenID
    }

    public func attach(view: any TodoListViewBridge) {
        nonisolated(unsafe) let view = view
        MainActor.assumeIsolated {
            screen?.attach { _ in view.rowsChanged() }
        }
    }

    public func detach() {
        MainActor.assumeIsolated { screen?.detach() }
    }

    /// 지금 목록. 화면이 이미 내려갔으면 빈 배열.
    public func rows() -> [TodoListRow] {
        MainActor.assumeIsolated {
            (screen?.currentState ?? []).map { TodoListRow(id: $0.id, title: $0.title, isDone: $0.isDone) }
        }
    }

    public func todoTapped(id: Int64) {
        MainActor.assumeIsolated { screen?.tapTodo(id: id) }
    }

    @MainActor private var screen: TodoListScreen? {
        controller?.screen(id: screenID, as: TodoListScreen.self)
    }
}
