import FeatureTodoListInterface
import FeatureTodoListTesting
import RIBs
import Testing
import TodoCore
import TodoCoreTesting

@testable import FeatureTodoList

/// 뷰가 받은 텍스트 파일(끌어다 놓기·파일 선택)을 `fileReceived` 하나로 넘기면 줄마다 할 일로 추가한다(#31).
@MainActor
final class TodoListImportTests {
    private let store = TodoStore()
    private let views = FakeTodoListViewFactory()
    private let parent = TestParentRouter()
    private let router: any ViewableRouting

    init() async {
        let dependency = FakeTodoListDependency(todoStore: store)
        router = TodoListBuilder(dependency: dependency, viewFactory: views).build(listener: FakeTodoListListener())
        parent.attach(router)
        await runCurrent()
    }

    isolated deinit {
        parent.detach(router)
    }

    private var view: FakeTodoListView { views.views.last! }

    @Test func addsEachNonEmptyTrimmedLine() async {
        view.listener?.handle(.fileReceived(name: "할일.txt", text: "  빨래 \r\n\n장보기\n   \n"))
        await runCurrent()

        #expect(store.todos.suffix(2).map(\.title) == ["빨래", "장보기"])
        #expect(view.state?.todos == store.todos)
        #expect(view.state?.notice == "할일.txt에서 2개를 추가했습니다")
    }

    @Test func fileWithoutLinesAddsNothing() async {
        view.listener?.handle(.fileReceived(name: "빈.txt", text: " \n\t\n"))
        await runCurrent()

        #expect(store.todos == TodoStore.sampleTodos)
        #expect(view.state?.notice == "빈.txt에 추가할 줄이 없습니다")
    }

    @Test func addsAtMostTheLimitAndReportsTheRest() async {
        let limit = TodoListInteractor.maxImportedTodos
        let lines = (1...(limit + 3)).map { "할 일 \($0)" }

        view.listener?.handle(.fileReceived(name: "많음.txt", text: lines.joined(separator: "\n")))
        await runCurrent()

        #expect(store.todos.count == TodoStore.sampleTodos.count + limit)
        #expect(view.state?.notice == "많음.txt에서 \(limit)개를 추가했습니다. 나머지 3줄은 넘겼습니다")
    }
}

/// 목록을 불러오기 전에는 추가하지 않는다. 불러온 목록이 추가한 항목을 덮어쓰기 때문이다.
@MainActor
final class TodoListImportBeforeLoadTests {
    private let store = TodoStore.unloaded()
    private let views = FakeTodoListViewFactory()
    private let parent = TestParentRouter()
    private let router: any ViewableRouting

    init() async {
        let dependency = FakeTodoListDependency(todoStore: store, todoRepository: FakeTodoRepository())
        router = TodoListBuilder(dependency: dependency, viewFactory: views).build(listener: FakeTodoListListener())
        parent.attach(router)
        await runCurrent()
    }

    isolated deinit {
        parent.detach(router)
    }

    @Test func refusesUntilLoaded() async {
        let view = views.views.last!

        view.listener?.handle(.fileReceived(name: "할일.txt", text: "빨래"))
        await runCurrent()

        #expect(store.todos.isEmpty)
        #expect(view.state?.notice == "목록을 불러온 뒤에 추가할 수 있습니다")
    }
}
