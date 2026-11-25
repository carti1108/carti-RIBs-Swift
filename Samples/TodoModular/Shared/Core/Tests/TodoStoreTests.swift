import Testing
import TodoCore

@MainActor
struct TodoStoreTests {
    @Test func unloadedStoreIsEmptyUntilLoaded() {
        let store = TodoStore.unloaded()
        #expect(!store.isLoaded)
        #expect(store.todos.isEmpty)

        store.load(TodoStore.sampleTodos)

        #expect(store.isLoaded)
        #expect(store.todos == TodoStore.sampleTodos)
    }

    @Test func storeWithInitialTodosIsLoaded() {
        #expect(TodoStore().isLoaded)
    }

    /// 상태 복원은 목록을 불러오기 전에 일어난다. 완료 표시는 기억해 뒀다가 불러온 목록에 입힌다.
    @Test func doneRestoredBeforeLoadIsAppliedOnLoad() {
        let store = TodoStore.unloaded()

        store.restoreDone([2, 3])
        #expect(store.doneIDs == [2, 3])

        store.load(TodoStore.sampleTodos)
        #expect(store.todos.filter(\.isDone).map(\.id) == [2, 3])
        #expect(store.doneIDs == [2, 3])
    }

    @Test func addAppendsTodosWithNewIDs() {
        let store = TodoStore()

        let added = store.add(titles: ["빨래", "장보기"])

        #expect(added == [Todo(id: 4, title: "빨래", isDone: false), Todo(id: 5, title: "장보기", isDone: false)])
        #expect(store.todos == TodoStore.sampleTodos + added)
    }

    @Test func addToEmptyStoreStartsAtOne() {
        let store = TodoStore(initial: [])

        #expect(store.add(titles: ["첫 할 일"]).map(\.id) == [1])
    }

    @Test func loadTellsSubscribers() async {
        let store = TodoStore.unloaded()
        var iterator = store.updates.makeAsyncIterator()
        #expect(await iterator.next() == [])

        store.load(TodoStore.sampleTodos)

        #expect(await iterator.next() == TodoStore.sampleTodos)
    }
}
