import JavaScriptKit
import LoginShared
import RIBs
import RIBsWeb

/// 루트 화면. 자식 RIB 화면(로그아웃·로그인) 하나를 담는다. 그릴 것이 없어 JS 뷰를 두지 않는다.
@MainActor
final class RootScreen: RootViewControllable, DOMScreen {
    let element: JSObject
    private let slot = WebScreenSlot()
    private let renderer: SlotRenderer

    init() {
        element = DOMBuilder.element("div", id: "root")
        renderer = SlotRenderer(slot: slot, container: element)
    }

    func showScreen(_ screen: any ViewControllable) { slot.show(screen) }
    func hideScreen(_ screen: any ViewControllable) { slot.hide(screen) }
}

/// 화면 자리(`element`)만 만들고, 안쪽은 JS 뷰(`LoggedOutViewBridge`)가 그린다.
@MainActor
final class LoggedOutScreen: LoggedOutViewContract, DOMScreen {
    weak var listener: (any LoggedOutPresentableListener)?
    let element: JSObject
    private let view: any LoggedOutViewBridge

    init(view: any LoggedOutViewBridge) {
        self.view = view
        element = DOMBuilder.element("section", id: "loggedOut")
        let handle = LoggedOutScreenHandle { [weak self] rawName in
            self?.listener?.handle(.loginTapped(rawName: rawName))
        }
        view.mount(host: element, handle: handle)
    }

    func render(_ state: LoggedOutViewState) {
        view.render(errorMessage: state.errorMessage, isLoading: state.isLoading)
    }
}

/// 화면 자리와 자식 화면 자리(`content`)를 만들고, 안쪽 배치는 JS 뷰(`LoggedInViewBridge`)에 맡긴다.
@MainActor
final class LoggedInScreen: LoggedInViewContract, DOMScreen {
    weak var listener: (any LoggedInPresentableListener)?
    let element: JSObject
    private let view: any LoggedInViewBridge
    private let slot = WebScreenSlot()
    private let renderer: SlotRenderer

    init(view: any LoggedInViewBridge) {
        self.view = view
        element = DOMBuilder.element("section", id: "loggedIn")
        let content = DOMBuilder.element("div", id: "loggedInContent")
        renderer = SlotRenderer(slot: slot, container: content)
        let handle = LoggedInScreenHandle { [weak self] in self?.listener?.handle(.logoutTapped) }
        view.mount(host: element, content: content, handle: handle)
    }

    func render(_ state: LoggedInViewState) {
        view.render(userName: state.userName, sessionSeconds: Int(state.sessionSeconds))
    }

    func showScreen(_ screen: any ViewControllable) { slot.show(screen) }
    func hideScreen(_ screen: any ViewControllable) { slot.hide(screen) }
}

@MainActor
final class TodoListScreen: TodoListViewContract, DOMScreen {
    weak var listener: (any TodoListPresentableListener)?
    let element: JSObject
    private let view: any TodoListViewBridge

    init(view: any TodoListViewBridge) {
        self.view = view
        element = DOMBuilder.element("ul", id: "todoList")
        let handle = TodoListScreenHandle { [weak self] id in self?.listener?.handle(.todoTapped(id: Int64(id))) }
        view.mount(host: element, handle: handle)
    }

    func render(_ state: TodoListViewState) {
        view.render(rows: state.todos.map { TodoListRow(id: Int($0.id), title: $0.title, isDone: $0.isDone) })
    }
}

@MainActor
final class TodoDetailScreen: TodoDetailViewContract, DOMScreen {
    weak var listener: (any TodoDetailPresentableListener)?
    let element: JSObject
    private let view: any TodoDetailViewBridge

    init(view: any TodoDetailViewBridge) {
        self.view = view
        element = DOMBuilder.element("section", id: "todoDetail")
        let handle = TodoDetailScreenHandle(
            onToggleDoneTapped: { [weak self] in self?.listener?.handle(.toggleDoneTapped) },
            onBackTapped: { [weak self] in self?.listener?.handle(.backTapped) }
        )
        view.mount(host: element, handle: handle)
    }

    func render(_ state: TodoDetailViewState) {
        view.render(title: state.title, isDone: state.isDone)
    }
}

/// JS가 `startLoginApp`으로 넘긴 화면별 웹 뷰.
struct WebViews {
    let loggedOut: any LoggedOutViewBridge
    let loggedIn: any LoggedInViewBridge
    let todoList: any TodoListViewBridge
    let todoDetail: any TodoDetailViewBridge
}

@MainActor
final class WebViewFactory: LoginViewFactory {
    private let views: WebViews

    init(views: WebViews) {
        self.views = views
    }

    func makeRootView() -> RootScreen { RootScreen() }
    func makeLoggedOutView() -> any LoggedOutViewContract { LoggedOutScreen(view: views.loggedOut) }
    func makeLoggedInView() -> any LoggedInViewContract { LoggedInScreen(view: views.loggedIn) }
    func makeTodoListView() -> any TodoListViewContract { TodoListScreen(view: views.todoList) }
    func makeTodoDetailView() -> any TodoDetailViewContract { TodoDetailScreen(view: views.todoDetail) }
}
