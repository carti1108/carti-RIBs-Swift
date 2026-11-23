import FeatureLoggedOutInterface
import Observation
import RIBs
import RIBsSwiftUI
import SwiftUI

/// 로그아웃 피처의 SwiftUI 뷰를 만든다.
@MainActor
public final class LoggedOutScreenFactory: LoggedOutViewFactory {
    public init() {}

    public func makeLoggedOutView() -> any LoggedOutViewContract { LoggedOutScreen() }
}

@MainActor
final class LoggedOutScreen: LoggedOutViewContract, SwiftUIRenderable {
    weak var listener: (any LoggedOutPresentableListener)?
    private let model = LoggedOutModel()

    func showError(_ message: String?) { model.errorMessage = message }
    func showLoading(_ isLoading: Bool) { model.isLoading = isLoading }

    func makeView() -> AnyView {
        AnyView(LoggedOutView(model: model) { [weak self] name in self?.listener?.didTapLogin(rawName: name) })
    }
}

@MainActor @Observable
final class LoggedOutModel {
    var errorMessage: String?
    var isLoading = false
}

private struct LoggedOutView: View {
    let model: LoggedOutModel
    let onLogin: (String) -> Void
    @State private var name = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("로그인").font(.largeTitle.bold())
            TextField("이름", text: $name)
                .textFieldStyle(.roundedBorder)
                .disabled(model.isLoading)
                .accessibilityIdentifier("nameField")
            if let message = model.errorMessage {
                Text(message).foregroundStyle(.red).accessibilityIdentifier("errorLabel")
            }
            if model.isLoading {
                ProgressView().accessibilityIdentifier("loadingIndicator")
            }
            Button("로그인") { onLogin(name) }
                .buttonStyle(.borderedProminent)
                .disabled(model.isLoading)
                .accessibilityIdentifier("loginButton")
        }
        .padding(24)
    }
}
