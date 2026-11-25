import LoginShared
import RIBs
import RIBsSwiftUI
import SwiftUI

/// 로그인 상태 RIB의 어댑터(ADR-0027). 자식 RIB 화면 슬롯을 들고, 순수 뷰에는 `child`로 넘긴다.
@MainActor
final class LoggedInScreen: LoggedInViewContract, SwiftUIRenderable {
    weak var listener: (any LoggedInPresentableListener)?
    let model = LoggedInModel()
    let slot = RIBScreenSlot()

    func render(_ state: LoggedInViewState) { model.state = state }
    func showScreen(_ screen: any ViewControllable) { slot.show(screen) }
    func hideScreen(_ screen: any ViewControllable) { slot.hide(screen) }

    func makeView() -> AnyView {
        AnyView(LoggedInContent(model: model, slot: slot) { [weak self] action in self?.listener?.handle(action) })
    }
}

private struct LoggedInContent: View {
    let model: LoggedInModel
    let slot: RIBScreenSlot
    let send: (LoggedInViewAction) -> Void

    var body: some View {
        LoggedInView(
            userName: model.state.userName,
            sessionSeconds: model.state.sessionSeconds,
            onLogout: { send(.logoutTapped) }
        ) {
            RIBSlotView(slot: slot)
        }
    }
}
