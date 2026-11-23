import JavaScriptEventLoop
import JavaScriptKit

// 브라우저 쪽 진입점. 앱은 JS가 시작한다(ADR-0022). 전체 앱은 피처별 웹 뷰를 모두 받고,
// 데모는 자기 피처의 뷰 하나만 받는다. 데모 페이지는 다른 피처의 JS를 불러오지 않는다.

@JS func startTodoApp(
    loggedOutView: any LoggedOutViewBridge,
    loggedInView: any LoggedInViewBridge,
    todoListView: any TodoListViewBridge,
    todoDetailView: any TodoDetailViewBridge
) {
    nonisolated(unsafe) let (loggedOutView, loggedInView, todoListView, todoDetailView) =
        (loggedOutView, loggedInView, todoListView, todoDetailView)
    MainActor.assumeIsolated {
        TodoWebApp.start(viewFactory: WebViewFactory(
            loggedOut: ViewMounts.loggedOut(loggedOutView),
            loggedIn: ViewMounts.loggedIn(loggedInView),
            todoList: ViewMounts.todoList(todoListView),
            todoDetail: ViewMounts.todoDetail(todoDetailView)
        ))
    }
}

@JS func startLoggedOutDemo(view: any LoggedOutViewBridge) {
    nonisolated(unsafe) let view = view
    MainActor.assumeIsolated { FeatureDemo.start { $0.loggedOut(ViewMounts.loggedOut(view)) } }
}

@JS func startLoggedInDemo(view: any LoggedInViewBridge) {
    nonisolated(unsafe) let view = view
    MainActor.assumeIsolated { FeatureDemo.start { $0.loggedIn(ViewMounts.loggedIn(view)) } }
}

@JS func startTodoListDemo(view: any TodoListViewBridge) {
    nonisolated(unsafe) let view = view
    MainActor.assumeIsolated { FeatureDemo.start { $0.todoList(ViewMounts.todoList(view)) } }
}

@JS func startTodoDetailDemo(view: any TodoDetailViewBridge) {
    nonisolated(unsafe) let view = view
    MainActor.assumeIsolated { FeatureDemo.start { $0.todoDetail(ViewMounts.todoDetail(view)) } }
}

JavaScriptEventLoop.installGlobalExecutor()
