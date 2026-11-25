import LoginShared
import RIBs
import RIBsSwiftUI
import SwiftUI

/// 로그아웃 상태 RIB의 어댑터(ADR-0027). 뷰 계약을 구현하고, 받은 상태를 풀어 순수 뷰(`Views/LoggedOutView.swift`)에 넘긴다.
@MainActor
final class LoggedOutScreen: LoggedOutViewContract, SwiftUIRenderable {
    weak var listener: (any LoggedOutPresentableListener)?
    let model = LoggedOutModel()

    func render(_ state: LoggedOutViewState) { model.state = state }

    func makeView() -> AnyView {
        AnyView(LoggedOutContent(model: model) { [weak self] action in self?.listener?.handle(action) })
    }
}

/// 모델을 관찰해 순수 뷰를 다시 그린다. 상태를 인자로 풀고 콜백을 액션으로 묶는다.
private struct LoggedOutContent: View {
    let model: LoggedOutModel
    let send: (LoggedOutViewAction) -> Void

    var body: some View {
        LoggedOutView(errorMessage: model.state.errorMessage, isLoading: model.state.isLoading) { rawName in
            send(.loginTapped(rawName: rawName))
        }
    }
}
