import FeatureTodoDetailInterface
import Observation
import RIBs
import RIBsSwiftUI
import SwiftUI

/// 할 일 상세 피처의 SwiftUI 뷰를 만든다. 뒤로 버튼은 닫기를 요청만 하고, 닫는 일은 부모 RIB이 한다.
@MainActor
public final class TodoDetailScreenFactory: TodoDetailViewFactory {
    public init() {}

    public func makeTodoDetailView() -> any TodoDetailViewContract { TodoDetailScreen() }
}

@MainActor
final class TodoDetailScreen: TodoDetailViewContract, SwiftUIRenderable {
    weak var listener: (any TodoDetailPresentableListener)?
    private let model = TodoDetailModel()

    func render(_ state: TodoDetailViewState) { model.state = state }

    func makeView() -> AnyView {
        AnyView(TodoDetailView(model: model) { [weak self] action in self?.listener?.handle(action) })
    }
}

@MainActor @Observable
final class TodoDetailModel {
    var state = TodoDetailViewState(title: "", isDone: false)
}

private struct TodoDetailView: View {
    let model: TodoDetailModel
    let send: (TodoDetailViewAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("← 목록") { send(.backTapped) }.accessibilityIdentifier("backButton")
            Text(model.state.title).font(.title3.bold()).accessibilityIdentifier("detailTitle")
            Button(model.state.isDone ? "완료 취소" : "완료로 표시") { send(.toggleDoneTapped) }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("toggleDoneButton")
        }
    }
}
