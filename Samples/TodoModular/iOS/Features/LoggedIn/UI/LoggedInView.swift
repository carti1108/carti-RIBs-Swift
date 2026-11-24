import SwiftUI

// 순수 뷰(ADR-0027). 값과 콜백만 받아 그린다. 이 타깃(`FeatureLoggedInUI`)은 SwiftUI에만 의존하고 공유 패키지와 RIBs를 모른다.

/// 자식 화면(할 일 목록·상세)은 `child`로 받는다. 무엇이 들어오는지 모른다.
public struct LoggedInView<Child: View>: View {
    let userName: String
    let sessionSeconds: Int64
    let onLogout: () -> Void
    let child: Child

    public init(
        userName: String,
        sessionSeconds: Int64,
        onLogout: @escaping () -> Void,
        @ViewBuilder child: () -> Child
    ) {
        self.userName = userName
        self.sessionSeconds = sessionSeconds
        self.onLogout = onLogout
        self.child = child()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(userName)님, 환영합니다").font(.title2.bold()).accessibilityIdentifier("welcomeLabel")
            Text("로그인 \(sessionSeconds)초").accessibilityIdentifier("sessionLabel")
            Button("로그아웃", action: onLogout)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("logoutButton")
            child
            Spacer()
        }
        .padding(24)
    }
}

#Preview {
    LoggedInView(userName: "carti", sessionSeconds: 12, onLogout: {}) {
        Text("자식 화면 자리").foregroundStyle(.secondary)
    }
}
