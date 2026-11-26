import FeatureLoggedIn
import FeatureLoggedInAndroid
import FeatureLoggedInInterface
import FeatureLoggedInTesting
import FeatureLoggedOut
import FeatureLoggedOutAndroid
import FeatureLoggedOutInterface
import FeatureTodoDetail
import FeatureTodoDetailAndroid
import FeatureTodoDetailInterface
import FeatureTodoDetailTesting
import FeatureTodoList
import FeatureTodoListAndroid
import FeatureTodoListInterface
import FeatureTodoListTesting
import RIBs
import RIBsAndroid
import TodoAndroidSupport
import TodoCore
import TodoCoreTesting

/// 단독 실행 앱이 띄울 수 있는 피처. Kotlin demo 모듈이 이 문자열로 고른다.
public enum DemoFeature: String, CaseIterable, Sendable {
    case loggedOut, loggedIn, todoList, todoDetail
}

/// 피처 하나만 띄운다(iOS `FeatureXxxExample`과 같은 역할). 부모는 `TestParentRouter`가 맡고,
/// 부모에게 갈 이벤트는 루트 화면의 `event`로 보여 준다. 자식 피처는 자리표시 화면으로 채운다.
@MainActor
public final class FeatureDemoController: RibController {
    private let feature: DemoFeature
    public let authService: any AuthService
    private let clock: any TodoClock
    private let stack: RenderStack
    private let root: HostRootScreen
    private let parent = TestParentRouter()
    private var router: (any ViewableRouting)?

    public init(
        feature: DemoFeature,
        authService: any AuthService,
        clock: any TodoClock = TaskSleepClock(),
        sink: @escaping (String) -> Void
    ) {
        self.feature = feature
        self.authService = authService
        self.clock = clock
        stack = RenderStack(sink: sink)
        root = HostRootScreen(context: stack.context)
    }

    /// 단독 실행은 상태를 되살리지 않는다.
    @discardableResult
    public func start(savedState: String?) -> Bool {
        precondition(router == nil, "FeatureDemoController.start called twice without stop")
        stack.host.show(root)
        let child = build()
        parent.attach(child)
        root.showScreen(child.viewControllable)
        router = child
        return false
    }

    public func screen<Screen: AndroidScreen>(id: Int64, as type: Screen.Type) -> Screen? {
        stack.registry.screen(id: id, as: type)
    }

    public func handleBackPress() -> Bool {
        (router as? any LoggedInRouting)?.handleBackPress() ?? false
    }

    public func saveState() -> String? { nil }

    public func stop() {
        guard let child = router else { return }
        parent.detach(child)
        root.hideScreen(child.viewControllable)
        stack.host.hide(root)
        router = nil
    }

    public var encodedTree: String { stack.renderer.encodedTree }

    private func build() -> any ViewableRouting {
        let context = stack.context
        switch feature {
        case .loggedOut:
            return LoggedOutBuilder(dependency: self, viewFactory: LoggedOutAndroidViewFactory(context: context))
                .build(listener: self)
        case .loggedIn:
            let dependency = FakeLoggedInDependency(
                clock: clock,
                listBuilder: PlaceholderTodoListBuilder(context: context),
                detailBuilder: PlaceholderTodoDetailBuilder(context: context)
            )
            return LoggedInBuilder(dependency: dependency, viewFactory: LoggedInAndroidViewFactory(context: context))
                .build(listener: self, userName: "demo")
        case .todoList:
            return TodoListBuilder(dependency: todoListDependency, viewFactory: TodoListAndroidViewFactory(context: context))
                .build(listener: self)
        case .todoDetail:
            let dependency = FakeTodoDetailDependency()
            guard let firstID = dependency.todoStore.todos.first?.id,
                  let child = TodoDetailBuilder(dependency: dependency, viewFactory: TodoDetailAndroidViewFactory(context: context))
                      .build(listener: self, todoID: firstID)
            else { preconditionFailure("sample store should contain at least one todo") }
            return child
        }
    }

    private lazy var todoListDependency = FakeTodoListDependency()
}

extension FeatureDemoController: LoggedOutDependency {}

extension FeatureDemoController: LoggedOutListener, LoggedInListener, TodoListListener, TodoDetailListener {
    public func didLogin(userName: String) { root.showEvent("didLogin(userName: \(userName))") }
    public func didRequestLogout() { root.showEvent("didRequestLogout()") }

    /// 선택한 항목을 토글해 목록 갱신까지 보여 준다.
    public func didSelectTodo(id: Int64) {
        root.showEvent("didSelectTodo(id: \(id))")
        todoListDependency.todoStore.toggle(id)
    }

    public func didRequireSignIn() { root.showEvent("didRequireSignIn()") }

    public func didRequestCloseDetail() { root.showEvent("didRequestCloseDetail()") }
}

/// 로그인 피처 단독 실행에서 자식 목록 대신 붙는다. 버튼으로 1번 선택을 보낸다.
@MainActor
private final class PlaceholderTodoListBuilder: TodoListBuildable {
    private let context: ScreenContext

    init(context: ScreenContext) { self.context = context }

    func build(listener: any TodoListListener) -> any ViewableRouting {
        let screen = PlaceholderScreen(context: context, title: "자리표시 목록", actionTitle: "1번 선택") { [weak listener] in
            listener?.didSelectTodo(id: 1)
        }
        return StubRouter(interactor: Interactor(), viewController: screen)
    }
}

@MainActor
private final class PlaceholderTodoDetailBuilder: TodoDetailBuildable {
    private let context: ScreenContext

    init(context: ScreenContext) { self.context = context }

    func build(listener: any TodoDetailListener, todoID: Int64) -> (any TodoDetailRouting)? {
        let screen = PlaceholderScreen(context: context, title: "자리표시 상세 #\(todoID)", actionTitle: "닫기") { [weak listener] in
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
