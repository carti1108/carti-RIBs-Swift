import FeatureLoggedIn
import FeatureLoggedInInterface
import FeatureLoggedInTesting
import FeatureLoggedInWeb
import FeatureLoggedOut
import FeatureLoggedOutInterface
import FeatureLoggedOutWeb
import FeatureTodoDetail
import FeatureTodoDetailInterface
import FeatureTodoDetailTesting
import FeatureTodoDetailWeb
import FeatureTodoList
import FeatureTodoListInterface
import FeatureTodoListTesting
import FeatureTodoListWeb
import RIBs
import TodoCore
import TodoCoreTesting
import TodoWebSupport

/// 피처 하나만 띄운다(iOS `FeatureXxxExample`, Android `feature/<f>/demo`와 같은 역할).
/// 부모는 `TestParentRouter`가 맡고, 부모에게 갈 이벤트는 루트 화면의 `#demoEvent`에 보여 준다.
/// 자식 피처는 자리표시 화면으로 채운다. 상태는 되살리지 않는다.
@MainActor
final class FeatureDemo: LoggedOutDependency {
    private static var current: FeatureDemo?

    let authService: any AuthService = DelayedAuthService(delay: Page.loginDelay())
    private let root = HostRootScreen()
    private let parent = TestParentRouter()
    private lazy var todoListDependency = FakeTodoListDependency()
    private var router: (any ViewableRouting)?

    static func start(_ build: (FeatureDemo) -> any ViewableRouting) {
        precondition(current == nil, "a feature demo is already running")
        let demo = FeatureDemo()
        _ = Page.appContainer.appendChild!(demo.root.element)
        let child = build(demo)
        demo.parent.attach(child)
        demo.root.showScreen(child.viewControllable)
        demo.router = child
        current = demo
    }

    func loggedOut(_ viewFactory: LoggedOutWebViewFactory) -> any ViewableRouting {
        LoggedOutBuilder(dependency: self, viewFactory: viewFactory).build(listener: self)
    }

    func loggedIn(_ viewFactory: LoggedInWebViewFactory) -> any ViewableRouting {
        let dependency = FakeLoggedInDependency(
            clock: TaskSleepClock(),
            listBuilder: PlaceholderTodoListBuilder(),
            detailBuilder: PlaceholderTodoDetailBuilder()
        )
        return LoggedInBuilder(dependency: dependency, viewFactory: viewFactory).build(listener: self, userName: "demo")
    }

    func todoList(_ viewFactory: TodoListWebViewFactory) -> any ViewableRouting {
        TodoListBuilder(dependency: todoListDependency, viewFactory: viewFactory).build(listener: self)
    }

    func todoDetail(_ viewFactory: TodoDetailWebViewFactory) -> any ViewableRouting {
        let dependency = FakeTodoDetailDependency()
        guard let firstID = dependency.todoStore.todos.first?.id,
              let child = TodoDetailBuilder(dependency: dependency, viewFactory: viewFactory)
                  .build(listener: self, todoID: firstID)
        else { preconditionFailure("sample store should contain at least one todo") }
        return child
    }
}

extension FeatureDemo: LoggedOutListener, LoggedInListener, TodoListListener, TodoDetailListener {
    func didLogin(userName: String) { root.showEvent("didLogin(userName: \(userName))") }
    func didRequestLogout() { root.showEvent("didRequestLogout()") }

    /// 선택한 항목을 토글해 목록 갱신까지 보여 준다.
    func didSelectTodo(id: Int64) {
        root.showEvent("didSelectTodo(id: \(id))")
        todoListDependency.todoStore.toggle(id)
    }

    func didRequireSignIn() { root.showEvent("didRequireSignIn()") }

    func didRequestCloseDetail() { root.showEvent("didRequestCloseDetail()") }
}

/// 로그인 피처 데모에서 자식 목록 대신 붙는다. 버튼으로 1번 선택을 보낸다.
@MainActor
private final class PlaceholderTodoListBuilder: TodoListBuildable {
    func build(listener: any TodoListListener) -> any ViewableRouting {
        let screen = PlaceholderScreen(title: "자리표시 목록", actionTitle: "1번 선택") { [weak listener] in
            listener?.didSelectTodo(id: 1)
        }
        return StubRouter(interactor: Interactor(), viewController: screen)
    }
}

@MainActor
private final class PlaceholderTodoDetailBuilder: TodoDetailBuildable {
    func build(listener: any TodoDetailListener, todoID: Int64) -> (any TodoDetailRouting)? {
        let screen = PlaceholderScreen(title: "자리표시 상세 #\(todoID)", actionTitle: "닫기") { [weak listener] in
            listener?.didRequestCloseDetail()
        }
        return PlaceholderTodoDetailRouter(todoID: todoID, viewController: screen)
    }
}

@MainActor
private final class PlaceholderTodoDetailRouter: ViewableRouter<Interactor, PlaceholderScreen>, TodoDetailRouting {
    let todoID: Int64

    init(todoID: Int64, viewController: PlaceholderScreen) {
        self.todoID = todoID
        super.init(interactor: Interactor(), viewController: viewController)
    }
}
