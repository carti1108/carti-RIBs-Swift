import FeatureTodoList
import FeatureTodoListInterface
import FeatureTodoListTesting
import FeatureTodoListUI
import Observation
import RIBsSwiftUI
import SwiftUI
import TodoCore
import TodoCoreTesting

/// 할 일 목록 피처만 띄운다. 항목을 누르면 부모 대신 받은 선택 이벤트로 그 항목을 토글해 갱신을 보여 준다.
@main
struct TodoListExampleApp: App {
    @State private var harness = TodoListExampleHarness()

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
final class TodoListExampleHarness: TodoListListener {
    let slot = RIBScreenSlot()
    private(set) var lastEvent = "부모 이벤트 없음"
    @ObservationIgnored private let dependency = FakeTodoListDependency()
    @ObservationIgnored private let parent = TestParentRouter()

    func start() {
        guard slot.current == nil else { return }
        let router = TodoListBuilder(dependency: dependency, viewFactory: TodoListScreenFactory()).build(listener: self)
        parent.attach(router)
        slot.show(router.viewControllable)
    }

    func didSelectTodo(id: Int64) {
        lastEvent = "didSelectTodo(id: \(id))"
        dependency.todoStore.toggle(id)
    }
}
