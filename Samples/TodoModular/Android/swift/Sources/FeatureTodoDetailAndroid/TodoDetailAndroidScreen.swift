import FeatureTodoDetailInterface
import RIBs
import TodoAndroidSupport

/// 할 일 상세 피처의 Android 화면을 만든다. 뒤로 버튼은 닫기를 요청만 하고, 닫는 일은 부모 RIB이 한다.
@MainActor
public final class TodoDetailAndroidViewFactory: TodoDetailViewFactory {
    nonisolated public static let kind = "todoDetail"
    private let context: ScreenContext

    public init(context: ScreenContext) {
        self.context = context
    }

    public func makeTodoDetailView() -> any TodoDetailViewContract { TodoDetailAndroidScreen(context: context) }
}

public struct TodoDetailScreenState: Equatable, Sendable {
    public var title = ""
    public var isDone = false
}

@MainActor
public final class TodoDetailAndroidScreen: BridgedScreen<TodoDetailScreenState>, TodoDetailViewContract {
    public weak var listener: (any TodoDetailPresentableListener)?

    init(context: ScreenContext) {
        super.init(kind: TodoDetailAndroidViewFactory.kind, context: context, initialState: TodoDetailScreenState())
    }

    public func showTodo(title: String, isDone: Bool) {
        setViewState(TodoDetailScreenState(title: title, isDone: isDone))
    }

    public func tapToggleDone() { listener?.didTapToggleDone() }
    public func tapBack() { listener?.didTapBack() }
}
