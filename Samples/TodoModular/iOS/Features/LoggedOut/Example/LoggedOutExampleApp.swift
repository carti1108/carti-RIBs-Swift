import FeatureLoggedOut
import FeatureLoggedOutInterface
import FeatureLoggedOutAdapter
import Observation
import RIBsSwiftUI
import SwiftUI
import TodoCore
import TodoCoreTesting

/// 로그아웃 피처만 띄운다. 부모 대신 받은 `didLogin`을 화면 아래에 보여 준다. 이름을 `fail`로 넣으면 실패한다.
@main
struct LoggedOutExampleApp: App {
    @State private var harness = LoggedOutExampleHarness()

    var body: some Scene {
        WindowGroup {
            VStack {
                RIBSlotView(slot: harness.slot)
                Text(harness.lastEvent).font(.footnote).accessibilityIdentifier("exampleEvent")
            }
            .onAppear { harness.start() }
        }
    }
}

@MainActor @Observable
final class LoggedOutExampleHarness: LoggedOutListener, LoggedOutDependency {
    let slot = RIBScreenSlot()
    let authService: any AuthService = DelayedAuthService(delay: .milliseconds(800))
    private(set) var lastEvent = "부모 이벤트 없음"
    @ObservationIgnored private let parent = TestParentRouter()

    func start() {
        guard slot.current == nil else { return }
        let router = LoggedOutBuilder(dependency: self, viewFactory: LoggedOutScreenFactory()).build(listener: self)
        parent.attach(router)
        slot.show(router.viewControllable)
    }

    func didLogin(userName: String) { lastEvent = "didLogin(userName: \(userName))" }
}
