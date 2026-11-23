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

    func showTodo(title: String, isDone: Bool) {
        model.title = title
        model.isDone = isDone
    }

    func makeView() -> AnyView {
        AnyView(TodoDetailView(
            model: model,
            onBack: { [weak self] in self?.listener?.didTapBack() },
            onToggle: { [weak self] in self?.listener?.didTapToggleDone() }
        ))
    }
}

@MainActor @Observable
final class TodoDetailModel {
    var title = ""
    var isDone = false
}

private struct TodoDetailView: View {
    let model: TodoDetailModel
    let onBack: () -> Void
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("← 목록", action: onBack).accessibilityIdentifier("backButton")
            Text(model.title).font(.title3.bold()).accessibilityIdentifier("detailTitle")
            Button(model.isDone ? "완료 취소" : "완료로 표시", action: onToggle)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("toggleDoneButton")
        }
    }
}
