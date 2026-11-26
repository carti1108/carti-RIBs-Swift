import FeatureTodoListInterface
import FeatureTodoListTesting
import RIBs
import Testing
import TodoCore
import TodoCoreTesting

@testable import FeatureTodoList

/// 저장소가 아직 비어 있을 때 목록이 `TodoRepository`에서 불러오는 흐름(ADR-0032).
@MainActor
final class TodoListLoadingTests {
    private let store = TodoStore.unloaded()
    private let repository = FakeTodoRepository()
    private let views = FakeTodoListViewFactory()
    private let parent = TestParentRouter()
    private let listener = FakeTodoListListener()
    private let router: any ViewableRouting

    init() async {
        let dependency = FakeTodoListDependency(todoStore: store, todoRepository: repository)
        router = TodoListBuilder(dependency: dependency, viewFactory: views).build(listener: listener)
        parent.attach(router)
        await runCurrent()
    }

    isolated deinit {
        parent.detach(router)
    }

    private var view: FakeTodoListView { views.views.last! }

    @Test func showsLoadingThenLoadedTodos() async {
        #expect(view.state == TodoListViewState(todos: [], isLoading: true))
        #expect(repository.requests == 1)

        repository.respond(.success(TodoStore.sampleTodos))
        await runCurrent()

        #expect(view.state == TodoListViewState(todos: TodoStore.sampleTodos))
        #expect(store.isLoaded)
    }

    /// 불러오기 전에 복원된 완료 표시는 첫 렌더부터 입혀져 있다. 표시 없는 목록을 먼저 그렸다 고치지 않는다.
    @Test func loadedTodosRenderOnceWithRestoredDoneMarks() async {
        store.restoreDone([2])
        let rendersBefore = view.states.count

        repository.respond(.success(TodoStore.sampleTodos))
        await runCurrent()

        #expect(view.states.count == rendersBefore + 1)
        #expect(view.state?.todos.filter(\.isDone).map(\.id) == [2])
        #expect(view.state?.isLoading == false)
    }

    /// 뗀 뒤에 늦게 도착한 응답은 버린다.
    @Test func responseArrivingAfterDetachIsDropped() async {
        parent.detach(router)
        repository.respond(.success(TodoStore.sampleTodos))
        await runCurrent()

        #expect(!store.isLoaded)
        #expect(view.state?.todos == [])
        parent.attach(router)  // deinit의 detach와 짝을 맞춘다.
    }

    /// 인증이 거절되면 다시 시도 문구 대신 부모에게 다시 로그인이 필요하다고 알린다.
    @Test func unauthorizedAsksParentToSignInAgain() async {
        repository.respond(.failure(.unauthorized))
        await runCurrent()

        #expect(listener.signInRequests == 1)
        #expect(view.state == TodoListViewState(todos: []))
    }

    @Test func failureShowsErrorAndRetryLoadsAgain() async {
        repository.respond(.failure(.unavailable))
        await runCurrent()
        #expect(view.state == TodoListViewState(todos: [], errorMessage: TodoListInteractor.loadError))

        view.listener?.handle(.retryTapped)
        await runCurrent()
        #expect(view.state == TodoListViewState(todos: [], isLoading: true))
        #expect(repository.requests == 2)

        repository.respond(.success(TodoStore.sampleTodos))
        await runCurrent()
        #expect(view.state == TodoListViewState(todos: TodoStore.sampleTodos))
    }

    @Test func retryWhileLoadingDoesNotStartAnotherRequest() async {
        view.listener?.handle(.retryTapped)
        await runCurrent()

        #expect(repository.requests == 1)
    }

    /// 떼면 요청이 취소되고 오류로 그리지 않는다. 다시 붙으면 처음부터 불러온다.
    @Test func detachCancelsLoadAndReattachLoadsAgain() async {
        parent.detach(router)
        await runCurrent()
        #expect(repository.cancellations == 1)
        #expect(view.state == TodoListViewState(todos: []))

        parent.attach(router)
        await runCurrent()
        #expect(repository.requests == 2)
        #expect(view.state == TodoListViewState(todos: [], isLoading: true))
    }
}

@MainActor
struct TodoListLoadedStoreTests {
    /// 이미 채워진 저장소면 다시 불러오지 않는다(상세에서 돌아왔을 때 등).
    @Test func loadedStoreIsNotLoadedAgain() async {
        let repository = FakeTodoRepository()
        let views = FakeTodoListViewFactory()
        let parent = TestParentRouter()
        let dependency = FakeTodoListDependency(todoStore: TodoStore(), todoRepository: repository)
        let router = TodoListBuilder(dependency: dependency, viewFactory: views).build(listener: FakeTodoListListener())
        parent.attach(router)
        await runCurrent()

        #expect(repository.requests == 0)
        #expect(views.views.last?.state == TodoListViewState(todos: TodoStore.sampleTodos))
        parent.detach(router)
    }
}
