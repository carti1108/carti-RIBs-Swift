import FeatureLoggedInWeb
import FeatureLoggedOutWeb
import FeatureTodoDetailWeb
import FeatureTodoListWeb
import TodoWebSupport

/// 피처의 웹 화면과 JS 뷰(브리지 프로토콜 구현)를 잇는다. 화면 상태를 브리지 인자로 풀고, 핸들 호출을 액션으로 묶는다(ADR-0025).
/// 피처 화면 타깃은 `@JS` 타입을 모른다. 둘을 아는 곳은 여기 하나다.
@MainActor
enum ViewMounts {
    static func loggedOut(_ view: any LoggedOutViewBridge) -> LoggedOutWebViewFactory {
        LoggedOutWebViewFactory { screen in
            let handle = LoggedOutScreenHandle { [weak screen] rawName in
                screen?.send(.loginTapped(rawName: rawName))
            }
            view.mount(host: screen.element, handle: handle)
            screen.attach { view.render(errorMessage: $0.errorMessage, isLoading: $0.isLoading) }
        }
    }

    static func loggedIn(_ view: any LoggedInViewBridge) -> LoggedInWebViewFactory {
        LoggedInWebViewFactory { screen in
            let handle = LoggedInScreenHandle { [weak screen] in screen?.send(.logoutTapped) }
            view.mount(host: screen.element, content: screen.content, handle: handle)
            screen.attach { view.render(userName: $0.userName, sessionSeconds: Int($0.sessionSeconds)) }
        }
    }

    static func todoList(_ view: any TodoListViewBridge) -> TodoListWebViewFactory {
        TodoListWebViewFactory { screen in
            let handle = TodoListScreenHandle(
                onTodoTapped: { [weak screen] id in screen?.send(.todoTapped(id: Int64(id))) },
                onRetryTapped: { [weak screen] in screen?.send(.retryTapped) },
                onFileReceived: { [weak screen] name, text in screen?.send(.fileReceived(name: name, text: text)) }
            )
            view.mount(host: screen.element, handle: handle)
            screen.attach { state in
                view.render(
                    rows: state.todos.map { TodoListRow(id: Int($0.id), title: $0.title, isDone: $0.isDone) },
                    isLoading: state.isLoading,
                    errorMessage: state.errorMessage,
                    notice: state.notice
                )
            }
        }
    }

    static func todoDetail(_ view: any TodoDetailViewBridge) -> TodoDetailWebViewFactory {
        TodoDetailWebViewFactory { screen in
            let handle = TodoDetailScreenHandle(
                onToggleDoneTapped: { [weak screen] in screen?.send(.toggleDoneTapped) },
                onBackTapped: { [weak screen] in screen?.send(.backTapped) },
                onTitleCopied: { [weak screen] succeeded in screen?.send(.titleCopied(succeeded: succeeded)) }
            )
            view.mount(host: screen.element, handle: handle)
            screen.attach { view.render(title: $0.title, isDone: $0.isDone, notice: $0.notice) }
        }
    }
}
