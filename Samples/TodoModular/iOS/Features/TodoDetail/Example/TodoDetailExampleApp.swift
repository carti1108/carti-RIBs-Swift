import FeatureTodoDetail
import FeatureTodoDetailInterface
import FeatureTodoDetailTesting
import FeatureTodoDetailUI
import Observation
import RIBsSwiftUI
import SwiftUI
import TodoCore
import TodoCoreTesting

/// 할 일 상세 피처만 띄운다. 첫 항목을 열고, 닫기 요청은 부모 대신 화면 아래에 보여 준다.
@main
struct TodoDetailExampleApp: App {
    @State private var harness = TodoDetailExampleHarness()

    var body: some Scene {
        WindowGroup {
            VStack {
                RIBSlotView(slot: harness.slot)
                Text(harness.lastEvent).font(.footnote).accessibilityIdentifier("exampleEvent")
            }
            .padding(24)
            .onAppear { harness.start() }
        }
    }
}

@MainActor @Observable
final class TodoDetailExampleHarness: TodoDetailListener {
    let slot = RIBScreenSlot()
    private(set) var lastEvent = "부모 이벤트 없음"
    @ObservationIgnored private let dependency = FakeTodoDetailDependency()
    @ObservationIgnored private let parent = TestParentRouter()

    func start() {
        guard slot.current == nil else { return }
        guard let firstID = dependency.todoStore.todos.first?.id,
              let router = TodoDetailBuilder(dependency: dependency, viewFactory: TodoDetailScreenFactory())
                  .build(listener: self, todoID: firstID)
        else {
            preconditionFailure("sample store should contain at least one todo")
        }
        parent.attach(router)
        slot.show(router.viewControllable)
    }

    func didRequestCloseDetail() { lastEvent = "didRequestCloseDetail()" }
}
