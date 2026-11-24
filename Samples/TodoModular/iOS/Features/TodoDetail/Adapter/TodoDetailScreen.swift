import FeatureTodoDetailInterface
import FeatureTodoDetailUI
import Observation
import RIBs
import RIBsSwiftUI
import SwiftUI

/// 할 일 상세 피처의 어댑터(ADR-0027)를 만든다.
@MainActor
public final class TodoDetailScreenFactory: TodoDetailViewFactory {
    public init() {}

    public func makeTodoDetailView() -> any TodoDetailViewContract { TodoDetailScreen() }
}

/// 뷰 계약을 구현하고, 받은 상태를 풀어 순수 뷰(`FeatureTodoDetailUI`)에 넘긴다.
@MainActor
final class TodoDetailScreen: TodoDetailViewContract, SwiftUIRenderable {
    weak var listener: (any TodoDetailPresentableListener)?
    private let model = TodoDetailModel()

    func render(_ state: TodoDetailViewState) { model.state = state }

    func makeView() -> AnyView {
        AnyView(TodoDetailContent(model: model) { [weak self] action in self?.listener?.handle(action) })
    }
}

@MainActor @Observable
final class TodoDetailModel {
    var state = TodoDetailViewState(title: "", isDone: false)
}

/// 모델을 관찰해 순수 뷰를 다시 그린다. 상태를 인자로 풀고 콜백을 액션으로 묶는다.
private struct TodoDetailContent: View {
    let model: TodoDetailModel
    let send: (TodoDetailViewAction) -> Void

    var body: some View {
        TodoDetailView(
            title: model.state.title,
            isDone: model.state.isDone,
            onBack: { send(.backTapped) },
            onToggleDone: { send(.toggleDoneTapped) }
        )
    }
}
