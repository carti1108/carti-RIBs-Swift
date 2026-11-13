import LoginShared
import RIBs
import RIBsSwiftUI
import SwiftUI

/// 로그아웃 상태 RIB의 뷰. 상태는 공유 코드가 `showError`·`showLoading`으로 넘기고, 입력은 `listener`로 돌려준다.
@MainActor
final class LoggedOutScreen: LoggedOutViewContract, SwiftUIRenderable {
    weak var listener: (any LoggedOutPresentableListener)?
    let model = LoggedOutModel()

    func showError(_ message: String?) { model.errorMessage = message }
    func showLoading(_ isLoading: Bool) { model.isLoading = isLoading }

    func makeView() -> AnyView {
        AnyView(LoggedOutView(model: model) { [weak self] name in self?.listener?.didTapLogin(rawName: name) })
    }
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
