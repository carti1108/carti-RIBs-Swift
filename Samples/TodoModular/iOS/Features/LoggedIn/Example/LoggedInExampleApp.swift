import FeatureLoggedIn
import FeatureLoggedInInterface
import FeatureLoggedInTesting
import FeatureLoggedInAdapter
import FeatureTodoDetailInterface
import FeatureTodoListInterface
import Observation
import RIBs
import RIBsSwiftUI
import SwiftUI
import TodoCore
import TodoCoreTesting

/// 로그인 피처만 띄운다. 자식(목록·상세) Impl 없이, 자식 자리에는 자리표시 화면을 붙인다.
/// 자리표시 목록의 버튼으로 선택 이벤트를 보내 상세 라우팅과 뒤로 가기를 확인한다.
@main
struct LoggedInExampleApp: App {
    @State private var harness = LoggedInExampleHarness()

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
final class LoggedInExampleHarness: LoggedInListener {
    let slot = RIBScreenSlot()
    private(set) var lastEvent = "부모 이벤트 없음"
    @ObservationIgnored private let parent = TestParentRouter()

    func start() {
        guard slot.current == nil else { return }
        let dependency = FakeLoggedInDependency(
            clock: TaskSleepClock(),
            listBuilder: PlaceholderTodoListBuilder(),
            detailBuilder: PlaceholderTodoDetailBuilder()
        )
        let router = LoggedInBuilder(dependency: dependency, viewFactory: LoggedInScreenFactory())
            .build(listener: self, userName: "example")
        parent.attach(router)
        slot.show(router.viewControllable)
    }

    func didRequestLogout() { lastEvent = "didRequestLogout()" }
}

/// 자식 화면 대신 그리는 단순한 SwiftUI 화면.
@MainActor
private final class PlaceholderScreen: TodoListViewControllable, TodoDetailViewControllable, SwiftUIRenderable {
    private let title: String
    private let actionTitle: String
    private let action: () -> Void

    init(title: String, actionTitle: String, action: @escaping () -> Void) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
    }

    func makeView() -> AnyView {
        AnyView(VStack(alignment: .leading, spacing: 8) {
            Text(title).foregroundStyle(.secondary)
            Button(actionTitle, action: action).accessibilityIdentifier("placeholderAction")
        })
    }
}

@MainActor
private final class PlaceholderTodoListBuilder: TodoListBuildable {
    func build(listener: any TodoListListener) -> any ViewableRouting {
        let screen = PlaceholderScreen(title: "자리표시 목록", actionTitle: "1번 선택") { [weak listener] in
            listener?.didSelectTodo(id: 1)
        }
        return StubRouter(interactor: Interactor(), viewController: screen)
    }
}

@MainActor
private final class PlaceholderTodoDetailBuilder: TodoDetailBuildable {
    func build(listener: any TodoDetailListener, todoID: Int64) -> (any TodoDetailRouting)? {
        let screen = PlaceholderScreen(title: "자리표시 상세 #\(todoID)", actionTitle: "닫기") { [weak listener] in
            listener?.didRequestCloseDetail()
        }
        return PlaceholderTodoDetailRouter(todoID: todoID, viewController: screen)
    }
}

@MainActor
private final class PlaceholderTodoDetailRouter: ViewableRouter<Interactor, PlaceholderScreen>, TodoDetailRouting {
    let todoID: Int64

    init(todoID: Int64, viewController: PlaceholderScreen) {
        self.todoID = todoID
        super.init(interactor: Interactor(), viewController: viewController)
    }
}
