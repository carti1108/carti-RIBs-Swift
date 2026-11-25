import SwiftUI

// 순수 뷰(ADR-0027). 값과 콜백만 받아 그린다. 이 타깃(`FeatureLoggedOutUI`)은 SwiftUI에만 의존하고 공유 패키지와 RIBs를 모른다.

/// 입력 중인 이름은 뷰가 들고 있다가 로그인 때 넘긴다.
public struct LoggedOutView: View {
    let errorMessage: String?
    let isLoading: Bool
    let onLogin: (String) -> Void
    @State private var name = ""

    public init(errorMessage: String?, isLoading: Bool, onLogin: @escaping (String) -> Void) {
        self.errorMessage = errorMessage
        self.isLoading = isLoading
        self.onLogin = onLogin
    }

    public var body: some View {
        VStack(spacing: 16) {
            Text("로그인").font(.largeTitle.bold())
            TextField("이름", text: $name)
                .textFieldStyle(.roundedBorder)
                .disabled(isLoading)
                .accessibilityIdentifier("nameField")
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).accessibilityIdentifier("errorLabel")
            }
            if isLoading {
                ProgressView().accessibilityIdentifier("loadingIndicator")
            }
            Button("로그인") { onLogin(name) }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)
                .accessibilityIdentifier("loginButton")
        }
        .padding(24)
    }
}

#Preview {
    LoggedOutView(errorMessage: "이름을 입력하세요", isLoading: false, onLogin: { _ in })
}
