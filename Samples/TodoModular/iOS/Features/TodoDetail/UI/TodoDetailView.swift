import SwiftUI

// 순수 뷰(ADR-0027). 값과 콜백만 받아 그린다. 이 타깃(`FeatureTodoDetailUI`)은 SwiftUI에만 의존하고 공유 패키지와 RIBs를 모른다.

/// 뒤로 버튼은 닫기를 요청만 한다.
public struct TodoDetailView: View {
    let title: String
    let isDone: Bool
    let onBack: () -> Void
    let onToggleDone: () -> Void

    public init(title: String, isDone: Bool, onBack: @escaping () -> Void, onToggleDone: @escaping () -> Void) {
        self.title = title
        self.isDone = isDone
        self.onBack = onBack
        self.onToggleDone = onToggleDone
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("← 목록", action: onBack).accessibilityIdentifier("backButton")
            Text(title).font(.title3.bold()).accessibilityIdentifier("detailTitle")
            Button(isDone ? "완료 취소" : "완료로 표시", action: onToggleDone)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("toggleDoneButton")
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview {
    TodoDetailView(title: "우유 사기", isDone: false, onBack: {}, onToggleDone: {})
}
