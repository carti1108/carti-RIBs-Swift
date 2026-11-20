import LoginShared
import RIBs
import RIBsAndroid

/// Kotlin `Screens.kt`가 고르는 화면 이름과 입력 이름. 두 쪽이 같은 문자열을 써야 한다.
public enum ScreenKind {
    public static let root = "root"
    public static let loggedOut = "loggedOut"
    public static let loggedIn = "loggedIn"
    public static let todoList = "todoList"
    public static let todoDetail = "todoDetail"
}

public enum ScreenAction {
    public static let logout = "logout"
    public static let selectTodo = "selectTodo"
    public static let toggleDone = "toggleDone"
    public static let back = "back"
}

/// 공유 코드가 RIB마다 요청하는 뷰를 Android 화면 객체로 만든다.
@MainActor
public final class AndroidLoginViewFactory: LoginViewFactory {
    private let renderer: AndroidRenderer
    private var loggedOutScreens: [WeakLoggedOutScreen] = []

    public init(renderer: AndroidRenderer) {
        self.renderer = renderer
    }

    /// 살아 있는 LoggedOut 화면을 화면 id로 찾는다. 다른 종류의 화면이거나 이미 내려갔으면 nil.
    func loggedOutScreen(id: Int64) -> LoggedOutScreen? {
        loggedOutScreens.lazy.compactMap(\.screen).first { $0.id == id }
    }

    public func makeRootView() -> RootScreen { RootScreen(renderer: renderer) }
    public func makeLoggedOutView() -> any LoggedOutViewContract {
        let screen = LoggedOutScreen(renderer: renderer)
        loggedOutScreens = loggedOutScreens.filter { $0.screen != nil } + [WeakLoggedOutScreen(screen: screen)]
        return screen
    }
    public func makeLoggedInView() -> any LoggedInViewContract { LoggedInScreen(renderer: renderer) }
    public func makeTodoListView() -> any TodoListViewContract { TodoListScreen(renderer: renderer) }
    public func makeTodoDetailView() -> any TodoDetailViewContract { TodoDetailScreen(renderer: renderer) }
}

public final class RootScreen: AndroidScreen, RootViewControllable {
    private lazy var slot = AndroidScreenSlot(owner: self)

    init(renderer: AndroidRenderer) { super.init(kind: ScreenKind.root, renderer: renderer) }

    public func showScreen(_ screen: any ViewControllable) { slot.show(screen) }
    public func hideScreen(_ screen: any ViewControllable) { slot.hide(screen) }

    override public func state() -> [String: RibValue] { ["child": slot.renderedValue] }
}

private struct WeakLoggedOutScreen {
    weak var screen: LoggedOutScreen?
}

/// 화면 트리에는 `kind`와 `id`만 싣는다. 상태와 입력은 문자열 키 대신 타입 있는 통로(`attach`/`send`)로 오간다.
/// 이름 입력값은 Kotlin(Compose) 화면이 들고 있다가 로그인 입력 때 인자로 넘긴다.
public final class LoggedOutScreen: AndroidScreen, LoggedOutViewContract {
    public weak var listener: (any LoggedOutPresentableListener)?
    private var viewState = LoggedOutViewState()
    private var onRender: ((LoggedOutViewState) -> Void)?

    init(renderer: AndroidRenderer) { super.init(kind: ScreenKind.loggedOut, renderer: renderer) }

    public func render(_ state: LoggedOutViewState) {
        viewState = state
        onRender?(state)
    }

    /// 플랫폼 뷰를 붙인다. 붙는 즉시 현재 상태를 한 번 그리게 한다.
    public func attach(onRender: @escaping (LoggedOutViewState) -> Void) {
        self.onRender = onRender
        onRender(viewState)
    }

    public func detach() {
        onRender = nil
    }

    public func send(_ action: LoggedOutViewAction) {
        listener?.handle(action)
    }
}

final class LoggedInScreen: AndroidScreen, LoggedInViewContract {
    weak var listener: (any LoggedInPresentableListener)?
    private var userName = ""
    private var sessionSeconds: Int64 = 0
    private lazy var slot = AndroidScreenSlot(owner: self)

    init(renderer: AndroidRenderer) { super.init(kind: ScreenKind.loggedIn, renderer: renderer) }

    func showUserName(_ name: String) {
        userName = name
        setNeedsRender()
    }

    func showSessionSeconds(_ seconds: Int64) {
        sessionSeconds = seconds
        setNeedsRender()
    }

    func showScreen(_ screen: any ViewControllable) { slot.show(screen) }
    func hideScreen(_ screen: any ViewControllable) { slot.hide(screen) }

    override func state() -> [String: RibValue] {
        ["userName": .string(userName), "sessionSeconds": .int(sessionSeconds), "child": slot.renderedValue]
    }

    override func handle(action: String, argument: String) {
        guard action == ScreenAction.logout else { return }
        listener?.didTapLogout()
    }
}

final class TodoListScreen: AndroidScreen, TodoListViewContract {
    weak var listener: (any TodoListPresentableListener)?
    private var todos: [Todo] = []

    init(renderer: AndroidRenderer) { super.init(kind: ScreenKind.todoList, renderer: renderer) }

    func showTodos(_ todos: [Todo]) {
        self.todos = todos
        setNeedsRender()
    }

    override func state() -> [String: RibValue] {
        let rows = todos.map { todo in
            RibValue.state(RibState(["id": .int(todo.id), "title": .string(todo.title), "isDone": .bool(todo.isDone)]))
        }
        return ["todos": .list(rows)]
    }

    override func handle(action: String, argument: String) {
        guard action == ScreenAction.selectTodo, let id = Int64(argument) else { return }
        listener?.didTapTodo(id: id)
    }
}

final class TodoDetailScreen: AndroidScreen, TodoDetailViewContract {
    weak var listener: (any TodoDetailPresentableListener)?
    private var title = ""
    private var isDone = false

    init(renderer: AndroidRenderer) { super.init(kind: ScreenKind.todoDetail, renderer: renderer) }

    func showTodo(title: String, isDone: Bool) {
        self.title = title
        self.isDone = isDone
        setNeedsRender()
    }

    override func state() -> [String: RibValue] { ["title": .string(title), "isDone": .bool(isDone)] }

    override func handle(action: String, argument: String) {
        switch action {
        case ScreenAction.toggleDone: listener?.didTapToggleDone()
        case ScreenAction.back: listener?.didTapBack()
        default: break
        }
    }
}
