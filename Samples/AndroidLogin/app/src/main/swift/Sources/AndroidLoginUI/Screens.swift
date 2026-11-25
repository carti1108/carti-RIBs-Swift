import LoginShared
import RIBs
import RIBsAndroid

/// Kotlin `Screens.kt`가 고르는 화면 이름. 두 쪽이 같은 문자열을 써야 한다.
public enum ScreenKind {
    public static let root = "root"
    public static let loggedOut = "loggedOut"
    public static let loggedIn = "loggedIn"
    public static let todoList = "todoList"
    public static let todoDetail = "todoDetail"
}

/// 공유 코드가 RIB마다 요청하는 뷰를 Android 화면 객체로 만든다.
@MainActor
public final class AndroidLoginViewFactory: LoginViewFactory {
    private let renderer: AndroidRenderer
    private var screens: [WeakScreen] = []

    public init(renderer: AndroidRenderer) {
        self.renderer = renderer
    }

    /// 살아 있는 화면을 화면 id와 타입으로 찾는다. 다른 종류의 화면이거나 이미 내려갔으면 nil.
    func screen<Screen: AndroidScreen>(id: Int64, as type: Screen.Type) -> Screen? {
        screens.lazy.compactMap(\.screen).first { $0.id == id } as? Screen
    }

    public func makeRootView() -> RootScreen { RootScreen(renderer: renderer) }
    public func makeLoggedOutView() -> any LoggedOutViewContract { track(LoggedOutScreen(renderer: renderer)) }
    public func makeLoggedInView() -> any LoggedInViewContract { track(LoggedInScreen(renderer: renderer)) }
    public func makeTodoListView() -> any TodoListViewContract { track(TodoListScreen(renderer: renderer)) }
    public func makeTodoDetailView() -> any TodoDetailViewContract { track(TodoDetailScreen(renderer: renderer)) }

    private func track<Screen: AndroidScreen>(_ screen: Screen) -> Screen {
        screens = screens.filter { $0.screen != nil } + [WeakScreen(screen: screen)]
        return screen
    }
}

private struct WeakScreen {
    weak var screen: AndroidScreen?
}

/// 상태를 타입 있는 통로로 내보내는 화면의 기반.
/// 화면 트리에는 `kind`와 `id`(자식이 있으면 `child`)만 싣고, 상태는 `attach`로 붙은 플랫폼 뷰에 직접 넘긴다.
public class BridgedScreen<State>: AndroidScreen {
    private var viewState: State
    private var onRender: ((State) -> Void)?

    init(kind: String, renderer: AndroidRenderer, initialState: State) {
        viewState = initialState
        super.init(kind: kind, renderer: renderer)
    }

    /// 플랫폼 뷰를 붙인다. 붙는 즉시 현재 상태를 한 번 그리게 한다.
    public final func attach(onRender: @escaping (State) -> Void) {
        self.onRender = onRender
        onRender(viewState)
    }

    public final func detach() {
        onRender = nil
    }

    /// 지금 상태. 플랫폼 뷰가 상태를 받는 대신 직접 읽어 갈 때 쓴다.
    public final var currentState: State { viewState }

    final func setViewState(_ state: State) {
        viewState = state
        onRender?(state)
    }
}

/// 상태도 입력도 없다. 자식 화면 하나를 화면 트리의 `child`로 내보낸다.
public final class RootScreen: AndroidScreen, RootViewControllable {
    private lazy var slot = AndroidScreenSlot(owner: self)

    init(renderer: AndroidRenderer) { super.init(kind: ScreenKind.root, renderer: renderer) }

    public func showScreen(_ screen: any ViewControllable) { slot.show(screen) }
    public func hideScreen(_ screen: any ViewControllable) { slot.hide(screen) }

    override public func state() -> [String: RibValue] { ["child": slot.renderedValue] }
}

/// 이름 입력값은 Kotlin(Compose) 화면이 들고 있다가 로그인 입력 때 인자로 넘긴다.
public final class LoggedOutScreen: BridgedScreen<LoggedOutViewState>, LoggedOutViewContract {
    public weak var listener: (any LoggedOutPresentableListener)?

    init(renderer: AndroidRenderer) {
        super.init(kind: ScreenKind.loggedOut, renderer: renderer, initialState: LoggedOutViewState())
    }

    public func render(_ state: LoggedOutViewState) { setViewState(state) }

    public func send(_ action: LoggedOutViewAction) { listener?.handle(action) }
}

public struct LoggedInScreenState: Equatable, Sendable {
    public var userName: String
    public var sessionSeconds: Int64

    public init(userName: String = "", sessionSeconds: Int64 = 0) {
        self.userName = userName
        self.sessionSeconds = sessionSeconds
    }
}

/// 자식 화면(할 일 목록·상세)은 화면 트리의 `child`로 내보낸다.
public final class LoggedInScreen: BridgedScreen<LoggedInScreenState>, LoggedInViewContract {
    public weak var listener: (any LoggedInPresentableListener)?
    private lazy var slot = AndroidScreenSlot(owner: self)

    init(renderer: AndroidRenderer) {
        super.init(kind: ScreenKind.loggedIn, renderer: renderer, initialState: LoggedInScreenState())
    }

    public func showUserName(_ name: String) {
        setViewState(LoggedInScreenState(userName: name, sessionSeconds: currentState.sessionSeconds))
    }

    public func showSessionSeconds(_ seconds: Int64) {
        setViewState(LoggedInScreenState(userName: currentState.userName, sessionSeconds: seconds))
    }

    public func showScreen(_ screen: any ViewControllable) { slot.show(screen) }
    public func hideScreen(_ screen: any ViewControllable) { slot.hide(screen) }

    public func tapLogout() { listener?.didTapLogout() }

    override public func state() -> [String: RibValue] { ["child": slot.renderedValue] }
}

public final class TodoListScreen: BridgedScreen<[Todo]>, TodoListViewContract {
    public weak var listener: (any TodoListPresentableListener)?

    init(renderer: AndroidRenderer) {
        super.init(kind: ScreenKind.todoList, renderer: renderer, initialState: [])
    }

    public func showTodos(_ todos: [Todo]) { setViewState(todos) }

    public func tapTodo(id: Int64) { listener?.didTapTodo(id: id) }
}

public struct TodoDetailScreenState: Equatable, Sendable {
    public var title: String
    public var isDone: Bool

    public init(title: String = "", isDone: Bool = false) {
        self.title = title
        self.isDone = isDone
    }
}

public final class TodoDetailScreen: BridgedScreen<TodoDetailScreenState>, TodoDetailViewContract {
    public weak var listener: (any TodoDetailPresentableListener)?

    init(renderer: AndroidRenderer) {
        super.init(kind: ScreenKind.todoDetail, renderer: renderer, initialState: TodoDetailScreenState())
    }

    public func showTodo(title: String, isDone: Bool) {
        setViewState(TodoDetailScreenState(title: title, isDone: isDone))
    }

    public func tapToggleDone() { listener?.didTapToggleDone() }
    public func tapBack() { listener?.didTapBack() }
}
