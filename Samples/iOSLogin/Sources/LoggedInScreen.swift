import LoginShared
import RIBs
import RIBsSwiftUI
import SwiftUI

/// 로그인 상태 RIB의 뷰. 머리말과 자식 RIB 화면(목록·상세) 하나를 그린다.
@MainActor
final class LoggedInScreen: LoggedInViewContract, SwiftUIRenderable {
    weak var listener: (any LoggedInPresentableListener)?
    let model = LoggedInModel()
    let slot = RIBScreenSlot()

    func showUserName(_ name: String) { model.userName = name }
    func showSessionSeconds(_ seconds: Int64) { model.sessionSeconds = seconds }
    func showScreen(_ screen: any ViewControllable) { slot.show(screen) }
    func hideScreen(_ screen: any ViewControllable) { slot.hide(screen) }

    func makeView() -> AnyView {
        AnyView(LoggedInView(model: model, slot: slot) { [weak self] in self?.listener?.didTapLogout() })
    }
}

private struct LoggedInView: View {
    let model: LoggedInModel
    let slot: RIBScreenSlot
    let onLogout: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(model.userName)님, 환영합니다").font(.title2.bold()).accessibilityIdentifier("welcomeLabel")
            Text("로그인 \(model.sessionSeconds)초").accessibilityIdentifier("sessionLabel")
            Button("로그아웃", action: onLogout)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("logoutButton")
            RIBSlotView(slot: slot)
            Spacer()
        }
        .padding(24)
    }
}
