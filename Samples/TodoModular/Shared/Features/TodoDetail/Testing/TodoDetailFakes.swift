import FeatureTodoDetailInterface
import RIBs
import TodoCore
import TodoCoreTesting

@MainActor
public final class FakeTodoDetailView: TodoDetailViewContract {
    public weak var listener: (any TodoDetailPresentableListener)?
    public private(set) var states: [TodoDetailViewState] = []
    public var state: TodoDetailViewState? { states.last }

    public init() {}

    public func render(_ state: TodoDetailViewState) { states.append(state) }
}

@MainActor
public final class FakeTodoDetailViewFactory: TodoDetailViewFactory {
    public private(set) var views: [FakeTodoDetailView] = []

    public init() {}

    public func makeTodoDetailView() -> any TodoDetailViewContract {
        let view = FakeTodoDetailView()
        views.append(view)
        return view
    }
}

@MainActor
public final class FakeTodoDetailListener: TodoDetailListener {
    public private(set) var closeRequests = 0

    public init() {}

    public func didRequestCloseDetail() { closeRequests += 1 }
}

@MainActor
public final class FakeTodoDetailDependency: TodoDetailDependency {
    public let todoStore: TodoStore

    public init(todoStore: TodoStore = TodoStore()) { self.todoStore = todoStore }
}

/// 부모 피처 테스트용 상세 Router. 열린 id만 기억한다.
@MainActor
public final class FakeTodoDetailRouter: ViewableRouter<Interactor, FakeTodoDetailView>, TodoDetailRouting {
    public let todoID: Int64

    public init(todoID: Int64, view: FakeTodoDetailView) {
        self.todoID = todoID
        super.init(interactor: Interactor(), viewController: view)
    }
}

/// 부모 피처 테스트용. `missingIDs`에 든 id는 nil을 돌려준다.
@MainActor
public final class FakeTodoDetailBuildable: TodoDetailBuildable {
    public var missingIDs: Set<Int64> = []
    public private(set) var listeners: [any TodoDetailListener] = []
    public private(set) var routers: [FakeTodoDetailRouter] = []

    public init() {}

    public func build(listener: any TodoDetailListener, todoID: Int64) -> (any TodoDetailRouting)? {
        guard !missingIDs.contains(todoID) else { return nil }
        listeners.append(listener)
        let router = FakeTodoDetailRouter(todoID: todoID, view: FakeTodoDetailView())
        routers.append(router)
        return router
    }
}
