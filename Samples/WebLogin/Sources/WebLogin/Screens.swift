import JavaScriptKit
import LoginShared
import RIBs
import RIBsWeb

/// 루트 화면. 자식 RIB 화면(로그아웃·로그인) 하나를 담는다.
@MainActor
final class RootScreen: RootViewControllable, DOMScreen {
    let element: JSObject
    private let slot = WebScreenSlot()
    private let renderer: SlotRenderer

    init(dom: DOMBuilder) {
        element = dom.element("div", id: "root")
        renderer = SlotRenderer(slot: slot, container: element)
    }

    func showScreen(_ screen: any ViewControllable) { slot.show(screen) }
    func hideScreen(_ screen: any ViewControllable) { slot.hide(screen) }
}

@MainActor
final class LoggedOutScreen: LoggedOutViewContract, DOMScreen {
    weak var listener: (any LoggedOutPresentableListener)?
    let element: JSObject
    private let dom = DOMBuilder()
    private let nameField: JSObject
    private let errorLabel: JSObject
    private let loadingIndicator: JSObject
    private var loginButton: JSObject?

    init() {
        element = dom.element("section", id: "loggedOut")
        nameField = dom.element("input", id: "nameField")
        nameField.placeholder = .string("이름")
        errorLabel = dom.element("p", id: "errorLabel")
        loadingIndicator = dom.element("p", id: "loadingIndicator", text: "로그인 중…")
        let loginButton = dom.button(id: "loginButton", text: "로그인") { [weak self] in
            guard let self else { return }
            listener?.handle(.loginTapped(rawName: nameField.value.string ?? ""))
        }
        self.loginButton = loginButton
        errorLabel.setHidden(true)
        loadingIndicator.setHidden(true)
        element.append(dom.element("h1", text: "로그인"), nameField, errorLabel, loadingIndicator, loginButton)
    }

    func render(_ state: LoggedOutViewState) {
        errorLabel.setText(state.errorMessage ?? "")
        errorLabel.setHidden(state.errorMessage == nil)
        loadingIndicator.setHidden(!state.isLoading)
        nameField.setDisabled(state.isLoading)
        loginButton?.setDisabled(state.isLoading)
    }
}

@MainActor
final class LoggedInScreen: LoggedInViewContract, DOMScreen {
    weak var listener: (any LoggedInPresentableListener)?
    let element: JSObject
    private let dom = DOMBuilder()
    private let welcomeLabel: JSObject
    private let sessionLabel: JSObject
    private let slot = WebScreenSlot()
    private var renderer: SlotRenderer?

    init() {
        element = dom.element("section", id: "loggedIn")
        welcomeLabel = dom.element("h2", id: "welcomeLabel")
        sessionLabel = dom.element("p", id: "sessionLabel")
        let content = dom.element("div", id: "loggedInContent")
        let logoutButton = dom.button(id: "logoutButton", text: "로그아웃") { [weak self] in
            self?.listener?.didTapLogout()
        }
        element.append(welcomeLabel, sessionLabel, logoutButton, content)
        renderer = SlotRenderer(slot: slot, container: content)
    }

    func showUserName(_ name: String) { welcomeLabel.setText("\(name)님, 환영합니다") }
    func showSessionSeconds(_ seconds: Int64) { sessionLabel.setText("로그인 \(seconds)초") }
    func showScreen(_ screen: any ViewControllable) { slot.show(screen) }
    func hideScreen(_ screen: any ViewControllable) { slot.hide(screen) }
}

@MainActor
final class TodoListScreen: TodoListViewContract, DOMScreen {
    weak var listener: (any TodoListPresentableListener)?
    let element: JSObject
    private var dom = DOMBuilder()

    init() {
        element = DOMBuilder().element("ul", id: "todoList")
    }

    func showTodos(_ todos: [Todo]) {
        // 이전 행의 클릭 클로저를 함께 버린다.
        dom = DOMBuilder()
        _ = element.replaceChildren!()
        for todo in todos {
            let row = dom.element("li")
            row.append(dom.button(id: "todoRow-\(todo.id)", text: (todo.isDone ? "✓ " : "") + todo.title) { [weak self] in
                self?.listener?.didTapTodo(id: todo.id)
            })
            element.append(row)
        }
    }
}

@MainActor
final class TodoDetailScreen: TodoDetailViewContract, DOMScreen {
    weak var listener: (any TodoDetailPresentableListener)?
    let element: JSObject
    private let dom = DOMBuilder()
    private let titleLabel: JSObject
    private var toggleButton: JSObject?

    init() {
        element = dom.element("section", id: "todoDetail")
        titleLabel = dom.element("h3", id: "detailTitle")
        let backButton = dom.button(id: "backButton", text: "← 목록") { [weak self] in self?.listener?.didTapBack() }
        let toggleButton = dom.button(id: "toggleDoneButton", text: "") { [weak self] in
            self?.listener?.didTapToggleDone()
        }
        self.toggleButton = toggleButton
        element.append(backButton, titleLabel, toggleButton)
    }

    func showTodo(title: String, isDone: Bool) {
        titleLabel.setText(title)
        toggleButton?.setText(isDone ? "완료 취소" : "완료로 표시")
    }
}

@MainActor
final class WebViewFactory: LoginViewFactory {
    func makeRootView() -> RootScreen { RootScreen(dom: DOMBuilder()) }
    func makeLoggedOutView() -> any LoggedOutViewContract { LoggedOutScreen() }
    func makeLoggedInView() -> any LoggedInViewContract { LoggedInScreen() }
    func makeTodoListView() -> any TodoListViewContract { TodoListScreen() }
    func makeTodoDetailView() -> any TodoDetailViewContract { TodoDetailScreen() }
}
