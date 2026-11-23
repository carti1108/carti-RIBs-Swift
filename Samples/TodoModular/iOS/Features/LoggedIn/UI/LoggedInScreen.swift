import FeatureLoggedInInterface
import Observation
import RIBs
import RIBsSwiftUI
import SwiftUI

/// 로그인 피처의 SwiftUI 뷰를 만든다. 자식(목록·상세) 화면은 슬롯으로만 받아 자식 UI 모듈을 모른다.
@MainActor
public final class LoggedInScreenFactory: LoggedInViewFactory {
    public init() {}

    public func makeLoggedInView() -> any LoggedInViewContract { LoggedInScreen() }
}

@MainActor
final class LoggedInScreen: LoggedInViewContract, SwiftUIRenderable {
    weak var listener: (any LoggedInPresentableListener)?
    private let model = LoggedInModel()
    private let slot = RIBScreenSlot()

    func showUserName(_ name: String) { model.userName = name }
    func showSessionSeconds(_ seconds: Int64) { model.sessionSeconds = seconds }
    func showScreen(_ screen: any ViewControllable) { slot.show(screen) }
    func hideScreen(_ screen: any ViewControllable) { slot.hide(screen) }

    func makeView() -> AnyView {
        AnyView(LoggedInView(model: model, slot: slot) { [weak self] in self?.listener?.didTapLogout() })
    }
}

@MainActor @Observable
final class LoggedInModel {
    var userName = ""
    var sessionSeconds: Int64 = 0
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
