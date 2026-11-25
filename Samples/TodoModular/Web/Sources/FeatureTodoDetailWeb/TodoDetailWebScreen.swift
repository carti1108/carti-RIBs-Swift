import FeatureTodoDetailInterface
import JavaScriptKit
import RIBs
import TodoWebSupport

/// 할 일 상세 피처의 웹 화면을 만든다. 화면을 그리는 JS 뷰는 조립 쪽이 `mount`에서 붙인다.
@MainActor
public final class TodoDetailWebViewFactory: TodoDetailViewFactory {
    private let mount: @MainActor (TodoDetailWebScreen) -> Void

    public init(mount: @escaping @MainActor (TodoDetailWebScreen) -> Void) {
        self.mount = mount
    }

    public func makeTodoDetailView() -> any TodoDetailViewContract {
        let screen = TodoDetailWebScreen()
        mount(screen)
        return screen
    }
}

@MainActor
public final class TodoDetailWebScreen: WebScreen<TodoDetailViewState>, TodoDetailViewContract {
    public weak var listener: (any TodoDetailPresentableListener)?

    init() {
        super.init(tag: "section", id: "todoDetail", initialState: TodoDetailViewState(title: "", isDone: false))
    }

    public func render(_ state: TodoDetailViewState) { setViewState(state) }

    public func send(_ action: TodoDetailViewAction) { listener?.handle(action) }
}
