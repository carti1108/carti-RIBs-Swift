import FeatureTodoListInterface
import RIBs
import TodoCore

public final class TodoListBuilder: Builder<any TodoListDependency>, TodoListBuildable {
    private let viewFactory: any TodoListViewFactory

    public init(dependency: any TodoListDependency, viewFactory: any TodoListViewFactory) {
        self.viewFactory = viewFactory
        super.init(dependency: dependency)
    }

    public func build(listener: any TodoListListener) -> any ViewableRouting {
        let view = viewFactory.makeTodoListView()
        let interactor = TodoListInteractor(
            presenter: view, todoStore: dependency.todoStore, todoRepository: dependency.todoRepository, listener: listener
        )
        return ViewableRouter<TodoListInteractor, any TodoListViewControllable>(
            interactor: interactor, viewController: view
        )
    }
}

/// 저장소의 목록을 구독해 뷰를 갱신한다. 저장소가 비어 있으면 `TodoRepository`에서 불러와 채운다(ADR-0032).
/// 구독과 불러오기는 활성 구간에서만 돈다.
final class TodoListInteractor: PresentableInteractor<any TodoListPresentable>, TodoListPresentableListener {
    static let loadError = "할 일을 불러오지 못했습니다"

    private let todoStore: TodoStore
    private let todoRepository: any TodoRepository
    private weak var listener: (any TodoListListener)?
    private var viewState = TodoListViewState()

    init(
        presenter: any TodoListPresentable,
        todoStore: TodoStore,
        todoRepository: any TodoRepository,
        listener: any TodoListListener
    ) {
        self.todoStore = todoStore
        self.todoRepository = todoRepository
        self.listener = listener
        super.init(presenter: presenter)
    }

    override func didBecomeActive() {
        presenter.listener = self
        let updates = todoStore.updates
        startTask { [weak self] in
            for await todos in updates {
                self?.update { $0.todos = todos }
            }
        }
        if !todoStore.isLoaded { load() }
    }

    override func willResignActive() {
        presenter.listener = nil
        // 취소된 요청이 남긴 로딩 표시를 지운다(ADR-0025).
        update { $0.isLoading = false }
    }

    func handle(_ action: TodoListViewAction) {
        switch action {
        case .todoTapped(let id): listener?.didSelectTodo(id: id)
        case .retryTapped:
            guard isActive, !viewState.isLoading, !todoStore.isLoaded else { return }
            load()
        case .fileReceived(let name, let text):
            importTodos(from: text, fileName: name)
        }
    }

    /// 파일 한 번에 더하는 할 일의 상한. 파일 내용은 사용자가 고른 외부 입력이라 크기를 공유 코드가 막는다.
    static let maxImportedTodos = 100

    /// 줄마다 앞뒤 공백을 지우고 빈 줄을 건너뛴다. 불러오기 전에는 더하지 않는다. 뒤이어 불러온 목록이 덮어쓰기 때문이다.
    private func importTodos(from text: String, fileName: String) {
        guard todoStore.isLoaded else {
            update { $0.notice = "목록을 불러온 뒤에 추가할 수 있습니다" }
            return
        }
        let titles = text.split(whereSeparator: \.isNewline)
            .map { line in String(line.drop(while: \.isWhitespace).reversed().drop(while: \.isWhitespace).reversed()) }
            .filter { !$0.isEmpty }
        guard !titles.isEmpty else {
            update { $0.notice = "\(fileName)에 추가할 줄이 없습니다" }
            return
        }
        let added = todoStore.add(titles: Array(titles.prefix(Self.maxImportedTodos)))
        let skipped = titles.count - added.count
        let todos = todoStore.todos
        update {
            $0.todos = todos
            $0.notice = "\(fileName)에서 \(added.count)개를 추가했습니다" + (skipped > 0 ? ". 나머지 \(skipped)줄은 넘겼습니다" : "")
        }
    }

    private func load() {
        update {
            $0.isLoading = true
            $0.errorMessage = nil
        }
        startTask { [weak self, todoRepository, todoStore] in
            do throws(TodoRepositoryError) {
                let loaded = try await todoRepository.loadTodos()
                // 떼인 뒤에 도착한 응답은 버린다. 다시 붙으면 처음부터 불러온다.
                guard !Task.isCancelled else { return }
                // 저장소가 복원된 완료 표시를 입힌 목록을 로딩 해제와 한 번에 그린다.
                // 저장소가 뒤이어 보내는 같은 목록은 다시 그리지 않는다.
                todoStore.load(loaded)
                let todos = todoStore.todos
                self?.update {
                    $0.isLoading = false
                    $0.todos = todos
                }
            } catch {
                switch error {
                case .cancelled: return
                case .unavailable:
                    guard !Task.isCancelled else { return }
                    self?.update {
                        $0.isLoading = false
                        $0.errorMessage = Self.loadError
                    }
                }
            }
        }
    }

    /// 상태가 실제로 바뀌었을 때만 그린다.
    private func update(_ change: (inout TodoListViewState) -> Void) {
        var next = viewState
        change(&next)
        guard next != viewState else { return }
        viewState = next
        presenter.render(next)
    }
}
