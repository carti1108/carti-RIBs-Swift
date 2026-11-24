import SwiftUI

// 순수 뷰(ADR-0027). 값과 콜백만 받아 그린다. SwiftUI만 import하고 공유 코드(`LoginShared`)와 RIBs를 모른다.

/// 입력 중인 이름은 뷰가 들고 있다가 로그인 때 넘긴다.
struct LoggedOutView: View {
    let errorMessage: String?
    let isLoading: Bool
    let onLogin: (String) -> Void
    @State private var name = ""

    var body: some View {
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
