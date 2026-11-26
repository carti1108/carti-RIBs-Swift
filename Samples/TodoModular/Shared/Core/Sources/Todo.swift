public struct Todo: Identifiable, Equatable, Sendable {
    public let id: Int64
    public let title: String
    public let isDone: Bool

    public init(id: Int64, title: String, isDone: Bool) {
        self.id = id
        self.title = title
        self.isDone = isDone
    }

    func with(isDone: Bool) -> Todo { Todo(id: id, title: title, isDone: isDone) }
}

/// 로그인한 동안 목록과 상세가 함께 쓰는 할 일 저장소. LoggedIn Component가 `shared`로 하나만 만든다.
@MainActor
public final class TodoStore {
    public static let sampleTodos = [
        Todo(id: 1, title: "우유 사기", isDone: false),
        Todo(id: 2, title: "RIB 문서 읽기", isDone: false),
        Todo(id: 3, title: "운동하기", isDone: false),
    ]

    public private(set) var todos: [Todo] {
        didSet { continuations.values.forEach { $0.yield(todos) } }
    }
    /// 목록을 한 번이라도 받았는지. 받기 전에는 `todos`가 비어 있다.
    public private(set) var isLoaded: Bool
    /// 불러오기 전에 복원된 완료 표시. `load`가 목록에 입힌다.
    private var pendingDoneIDs: [Int64] = []
    private var continuations: [UInt64: AsyncStream<[Todo]>.Continuation] = [:]
    private var nextID: UInt64 = 0

    /// 목록을 이미 가진 저장소. 테스트와 미리보기가 쓴다.
    public init(initial: [Todo] = TodoStore.sampleTodos) {
        todos = initial
        isLoaded = true
    }

    private init() {
        todos = []
        isLoaded = false
    }

    /// 아직 불러오지 않은 빈 저장소. `TodoRepository`에서 받은 목록을 `load`로 채운다.
    public static func unloaded() -> TodoStore { TodoStore() }

    public func load(_ loaded: [Todo]) {
        let done = pendingDoneIDs
        pendingDoneIDs = []
        isLoaded = true
        todos = done.isEmpty ? loaded : loaded.map { $0.with(isDone: done.contains($0.id)) }
    }

    /// 현재 목록을 먼저 보내고 바뀔 때마다 다시 보낸다(Kotlin `StateFlow`).
    public var updates: AsyncStream<[Todo]> {
        AsyncStream { continuation in
            continuation.yield(todos)
            let id = nextID
            nextID += 1
            continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in self?.continuations[id] = nil }
            }
        }
    }

    public func find(_ id: Int64) -> Todo? { todos.first { $0.id == id } }

    public func toggle(_ id: Int64) {
        todos = todos.map { $0.id == id ? $0.with(isDone: !$0.isDone) : $0 }
    }

    /// 제목마다 완료되지 않은 할 일을 끝에 더하고, 더한 항목을 돌려준다. id는 지금 가장 큰 id 다음부터 붙인다.
    /// 이 샘플은 서버에 보내지 않는다. 상태 저장은 완료 표시만 하므로 앱을 다시 열면 사라진다.
    @discardableResult
    public func add(titles: [String]) -> [Todo] {
        let firstID = (todos.map(\.id).max() ?? 0) + 1
        let added = titles.enumerated().map { Todo(id: firstID + Int64($0.offset), title: $0.element, isDone: false) }
        todos += added
        return added
    }

    public var doneIDs: [Int64] { isLoaded ? todos.filter(\.isDone).map(\.id) : pendingDoneIDs }

    public func restoreDone(_ ids: [Int64]) {
        guard isLoaded else {
            pendingDoneIDs = ids
            return
        }
        todos = todos.map { $0.with(isDone: ids.contains($0.id)) }
    }
}
