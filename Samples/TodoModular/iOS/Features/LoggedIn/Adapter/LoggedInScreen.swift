import FeatureLoggedInInterface
import FeatureLoggedInUI
import Observation
import RIBs
import RIBsSwiftUI
import SwiftUI

/// 로그인 피처의 어댑터(ADR-0027)를 만든다. 자식(목록·상세) 화면은 스택으로만 받아 자식 피처를 모른다.
@MainActor
public final class LoggedInScreenFactory: LoggedInViewFactory {
    public init() {}

    public func makeLoggedInView() -> any LoggedInViewContract { LoggedInScreen() }
}

/// 뷰 계약을 구현하고, 받은 상태를 풀어 순수 뷰(`FeatureLoggedInUI`)에 넘긴다.
@MainActor
final class LoggedInScreen: LoggedInViewContract, SwiftUIRenderable {
    weak var listener: (any LoggedInPresentableListener)?
    private let model = LoggedInModel()
    private let stack = RIBScreenStack()

    init() {
        // 스와이프나 내비게이션 바의 뒤로 버튼으로 상세가 닫히면 공유 코드에 알린다(ADR-0030).
        stack.onDismissedByUser = { [weak self] _ in self?.listener?.handle(.detailDismissedByUser) }
    }

    func render(_ state: LoggedInViewState) { model.state = state }
    func showList(_ screen: any ViewControllable) { stack.setRoot(screen) }
    func showDetail(_ screen: any ViewControllable) { stack.push(screen) }
    func hideDetail(_ screen: any ViewControllable) { stack.pop(screen) }

    func makeView() -> AnyView {
        AnyView(LoggedInContent(model: model, stack: stack) { [weak self] action in self?.listener?.handle(action) })
    }
}

@MainActor @Observable
final class LoggedInModel {
    var state = LoggedInViewState(userName: "")
}

/// 모델을 관찰해 순수 뷰를 다시 그린다. 상태를 인자로 풀고 콜백을 액션으로 묶는다.
private struct LoggedInContent: View {
    let model: LoggedInModel
    let stack: RIBScreenStack
    let send: (LoggedInViewAction) -> Void

    var body: some View {
        LoggedInView(
            userName: model.state.userName,
            sessionSeconds: model.state.sessionSeconds,
            onLogout: { send(.logoutTapped) }
        ) {
            RIBStackView(stack: stack)
        }
    }
}
