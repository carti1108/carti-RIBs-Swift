import Testing
@testable import RIBs

/// 읽기 전용 리뷰에서 나온 결함의 회귀 테스트.
@MainActor
struct ReviewRegressionTests {
    private let log = EventLog()

    private func node(_ name: String) -> RecordingRouter {
        RecordingRouter(name, log: log)
    }

    /// 스트림이 끝까지 읽혔는지(= finish됐는지)와 읽은 값을 돌려준다.
    private func collect(_ stream: AsyncStream<RouterLifecycle>, afterward: () -> Void = {}) async -> (values: [RouterLifecycle], finished: Bool) {
        let values = Box<[RouterLifecycle]>([])
        let finished = Box(false)
        let reader = Task { @MainActor in
            for await event in stream { values.value.append(event) }
            finished.value = true
        }
        await drainMainActor()
        afterward()
        await drainMainActor()
        let result = (values.value, finished.value)
        reader.cancel()
        return result
    }

    @Test func setSubtreeActive_skipsSiblingDetachedDuringActivationCallback() {
        // Given: g → p → (a, b). p를 떼어 하위 트리를 비활성으로 만든다.
        let grandparent = node("g")
        let parent = node("p")
        let first = node("a")
        let second = node("b")
        grandparent.attachChild(parent)
        parent.attachChild(first)
        parent.attachChild(second)
        grandparent.detachChild(parent)
        first.interactor.onDidBecomeActive = { parent.detachChild(second) }

        // When: 다시 붙이면 a 활성화 콜백에서 b가 떨어진다
        grandparent.attachChild(parent)

        // Then
        #expect(first.interactor.isActive)
        #expect(!second.interactor.isActive)
        #expect(parent.children.count == 1)
    }

    @Test func mount_afterUnmount_runsDidLoadAgainAndReattachesChildren() {
        // Given
        let root = node("r")
        root.onDidLoad = { root.attachChild(self.node("c")) }
        root.mount().unmount()

        // When
        let mount = root.mount()

        // Then
        #expect(root.didLoadCount == 2)
        #expect(root.children.count == 1)
        #expect(root.children.first?.interactable.isActive == true)
        mount.unmount()
    }

    @Test func lifecycle_finishesAfterDidLoad() async {
        // Given
        let router = node("a")

        // When
        let result = await collect(router.lifecycle) { router.load() }

        // Then
        #expect(result.values == [.didLoad])
        #expect(result.finished)
    }

    @Test func lifecycle_subscribedAfterLoad_emitsDidLoadThenFinishes() async {
        // Given
        let router = node("a")
        router.load()

        // When
        let result = await collect(router.lifecycle)

        // Then
        #expect(result.values == [.didLoad])
        #expect(result.finished)
    }

    @Test func lifecycle_subscribedAfterUnmount_doesNotReplayStaleDidLoad() async {
        // Given
        let router = node("a")
        router.mount().unmount()

        // When
        let result = await collect(router.lifecycle)

        // Then
        #expect(result.values.isEmpty)
        #expect(!result.finished)
    }

    @Test func lifecycle_pendingSubscriberFinishesOnUnmount() async {
        // Given
        let router = node("a")
        let mount = router.mount()
        mount.unmount()
        let stream = router.lifecycle

        // When: 다시 mount 후 unmount
        let result = await collect(stream) {
            router.mount().unmount()
        }

        // Then
        #expect(result.values == [.didLoad])
        #expect(result.finished)
    }

    @Test func confineTo_doesNotRetainScopeAndFinishesWhenScopeIsGone() async {
        // Given
        let (source, input) = AsyncStream<Int>.makeStream()
        var interactor: Interactor? = Interactor()
        weak let weakInteractor = interactor
        let confined = source.confineTo(interactor!)
        let finished = Box(false)
        let reader = Task { @MainActor in
            for await _ in confined {}
            finished.value = true
        }
        await drainMainActor()

        // When
        interactor = nil
        input.yield(1)
        await drainMainActor()

        // Then
        #expect(weakInteractor == nil)
        #expect(finished.value)
        reader.cancel()
        input.finish()
    }
}
