import RIBs
import TodoCore

public struct TodoDetailViewState: Equatable, Sendable {
    public var title: String
    public var isDone: Bool
    /// 방금 한 일의 결과 문구(예: 제목 복사). 없으면 뷰는 아무것도 보여 주지 않는다.
    public var notice: String?

    public init(title: String, isDone: Bool, notice: String? = nil) {
        self.title = title
        self.isDone = isDone
        self.notice = notice
    }
}

public enum TodoDetailViewAction: Equatable, Sendable {
    case toggleDoneTapped
    case backTapped
    /// 뷰가 제목을 플랫폼 클립보드에 쓴 결과. 클립보드는 뷰가 다루고 공유 코드는 결과만 받는다(#31).
    case titleCopied(succeeded: Bool)
}

@MainActor
public protocol TodoDetailPresentableListener: AnyObject {
    func handle(_ action: TodoDetailViewAction)
}

@MainActor
public protocol TodoDetailPresentable: Presentable {
    var listener: (any TodoDetailPresentableListener)? { get set }
    func render(_ state: TodoDetailViewState)
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
