import RIBs
import TodoCore

@MainActor
public protocol TodoDetailPresentableListener: AnyObject {
    func didTapToggleDone()
    func didTapBack()
}

@MainActor
public protocol TodoDetailPresentable: Presentable {
    var listener: (any TodoDetailPresentableListener)? { get set }
    func showTodo(title: String, isDone: Bool)
}

@MainActor
public protocol TodoDetailViewControllable: ViewControllable {}

@MainActor
public protocol TodoDetailViewContract: TodoDetailPresentable, TodoDetailViewControllable {}

@MainActor
public protocol TodoDetailViewFactory: AnyObject {
    func makeTodoDetailView() -> any TodoDetailViewContract
}

@MainActor
public protocol TodoDetailDependency: Dependency {
    var todoStore: TodoStore { get }
}

/// 자식 → 부모: 상세를 닫아 달라는 의도. 닫는 일(라우팅)은 부모가 한다.
@MainActor
public protocol TodoDetailListener: AnyObject {
    func didRequestCloseDetail()
}

/// 부모가 저장 상태에 열린 상세 id를 넣을 때 쓴다.
@MainActor
public protocol TodoDetailRouting: ViewableRouting {
    var todoID: Int64 { get }
}

@MainActor
public protocol TodoDetailBuildable: Buildable {
    /// `todoID`가 저장소에 없으면 nil(복원 시 사라진 항목 등).
    func build(listener: any TodoDetailListener, todoID: Int64) -> (any TodoDetailRouting)?
}
