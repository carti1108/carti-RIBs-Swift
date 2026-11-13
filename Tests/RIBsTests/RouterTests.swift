import Testing
@testable import RIBs

@MainActor
struct RouterTests {
    private let log = EventLog()

    private func node(_ name: String) -> RecordingRouter {
        RecordingRouter(name, log: log)
    }

    @Test func load_callsDidLoadOnceAndEmitsDidLoad() async {
        // Given
        let router = node("a")
        let stream = router.lifecycle

        // When
        router.load()
        router.load()

        // Then
        #expect(router.isLoaded)
        #expect(router.didLoadCount == 1)
        #expect(await stream.take(1) == [.didLoad])
    }

    @Test func lifecycle_subscribedAfterLoad_replaysDidLoad() async {
        // Given
        let router = node("a")
        router.load()

        // When
        let stream = router.lifecycle

        // Then
        #expect(await stream.take(1) == [.didLoad])
    }

    @Test func attachChild_activatesChildThenLoadsIt() {
        // Given
        let parent = node("p")
        let child = node("c")

        // When
        parent.attachChild(child)

        // Then
        #expect(parent.children.count == 1 && parent.children[0] === child)
        #expect(child.interactor.isActive && child.isLoaded)
        #expect(log.entries == ["c.didBecomeActive", "c.didLoad"])
    }

    @Test func attachChild_assignsTypeNameAsDefaultTag() {
        // Given
        let parent = node("p")
        let child = node("c")

        // When
        parent.attachChild(child)

        // Then
        #expect(child.tag == "RecordingRouter")
    }

    @Test func attachChild_acceptsRoutingThatIsNotARouter() {
        // Given
        let parent = node("p")
        let fake = FakeRouting()

        // When
        parent.attachChild(fake)

        // Then
        #expect(fake.interactable.isActive)
        #expect(fake.loadCount == 1)
        #expect(parent.children.count == 1)
    }

    @Test func detachChild_deactivatesChildAndRemovesIt() {
        // Given
        let parent = node("p")
        let child = node("c")
        parent.attachChild(child)
        log.clear()

        // When
        parent.detachChild(child)

        // Then
        #expect(parent.children.isEmpty)
        #expect(!child.interactor.isActive)
        #expect(log.entries == ["c.willResignActive"])
    }

    @Test func detachChild_deactivatesSubtreeInPreOrderAndKeepsIt() {
        // Given
        let parent = node("p")
        let child = node("c")
        let grandChild = node("g")
        parent.attachChild(child)
        child.attachChild(grandChild)
        log.clear()

        // When
        parent.detachChild(child)

        // Then
        #expect(log.entries == ["c.willResignActive", "g.willResignActive"])
        #expect(child.children.count == 1)
        #expect(!grandChild.interactor.isActive)
    }

    @Test func reattachChild_reactivatesKeptSubtreeWithoutReloading() {
        // Given
        let parent = node("p")
        let child = node("c")
        parent.attachChild(child)
        child.attachChild(node("g"))
        parent.detachChild(child)
        log.clear()

        // When
        parent.attachChild(child)

        // Then
        #expect(log.entries == ["c.didBecomeActive", "g.didBecomeActive"])
        #expect(child.didLoadCount == 1)
    }

    @Test func saveInstanceState_restoresInteractorStateByTag() {
        // Given
        let parent = node("p")
        let child = node("c")
        parent.attachChild(child, tag: "child")
        child.interactor.valueToSave = "kept"
        let saved = parent.saveInstanceState()

        // When
        let restoredParent = node("p")
        let mount = restoredParent.mount(savedInstanceState: saved)
        let restoredChild = node("c")
        restoredParent.attachChild(restoredChild, tag: "child")

        // Then
        #expect(restoredChild.interactor.restoredValue == "kept")
        #expect(restoredChild.tag == "child")
        mount.unmount()
    }

    @Test func saveInstanceState_storesInteractorAndChildrenUnderFixedKeys() {
        // Given
        let parent = node("p")
        parent.interactor.valueToSave = "root"
        parent.attachChild(node("c"), tag: "c")
        parent.attachChild(FakeRouting())

        // When
        let saved = parent.saveInstanceState()

        // Then
        #expect(saved.keys == [RecordingRouter.childRoutersKey, RecordingRouter.interactorKey])
        #expect(saved[RecordingRouter.interactorKey]?.stateValue?["value"] == .string("root"))
        #expect(saved[RecordingRouter.childRoutersKey]?.stateValue?.keys == ["c"])
    }

    @Test func saveInstanceState_withTwoSameTypeChildrenUsingDefaultTag_keepsBothStates() {
        // Given
        let parent = node("p")
        let first = node("first")
        let second = node("second")
        first.interactor.valueToSave = "1"
        second.interactor.valueToSave = "2"
        parent.attachChild(first)
        parent.attachChild(second)

        // When
        let children = parent.saveInstanceState()[RecordingRouter.childRoutersKey]?.stateValue

        // Then
        #expect(children?.keys.count == 2)
    }

    @Test func savedInstanceState_isNilWhenNothingWasSaved() {
        // Given
        let parent = node("p")
        let child = node("c")

        // When
        parent.attachChild(child, tag: "x")

        // Then
        #expect(child.interactor.savedInstanceState == nil)
    }

    @Test func handleBackPress_delegatesToInteractor() {
        // Given
        let router = node("a")

        // When / Then
        #expect(router.handleBackPress() == false)
        router.interactor.consumesBack = true
        #expect(router.handleBackPress() == true)
    }
}
