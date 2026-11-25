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

    func render(_ state: LoggedOutViewState) { model.state = state }

    func makeView() -> AnyView {
        AnyView(LoggedOutView(model: model) { [weak self] action in self?.listener?.handle(action) })
    }
}

@MainActor @Observable
final class LoggedOutModel {
    var state = LoggedOutViewState()
}

private struct LoggedOutView: View {
    let model: LoggedOutModel
    let send: (LoggedOutViewAction) -> Void
    @State private var name = ""

    var body: some View {
        let state = model.state
        VStack(spacing: 16) {
            Text("로그인").font(.largeTitle.bold())
            TextField("이름", text: $name)
                .textFieldStyle(.roundedBorder)
                .disabled(state.isLoading)
                .accessibilityIdentifier("nameField")
            if let message = state.errorMessage {
                Text(message).foregroundStyle(.red).accessibilityIdentifier("errorLabel")
            }
            if state.isLoading {
                ProgressView().accessibilityIdentifier("loadingIndicator")
            }
            Button("로그인") { send(.loginTapped(rawName: name)) }
                .buttonStyle(.borderedProminent)
                .disabled(state.isLoading)
                .accessibilityIdentifier("loginButton")
        }
        .padding(24)
    }
}
