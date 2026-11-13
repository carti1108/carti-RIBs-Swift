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
    private var continuations: [UInt64: AsyncStream<[Todo]>.Continuation] = [:]
    private var nextID: UInt64 = 0

    public init(initial: [Todo] = TodoStore.sampleTodos) {
        todos = initial
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

    public var doneIDs: [Int64] { todos.filter(\.isDone).map(\.id) }

    public func restoreDone(_ ids: [Int64]) {
        todos = todos.map { $0.with(isDone: ids.contains($0.id)) }
    }
}
