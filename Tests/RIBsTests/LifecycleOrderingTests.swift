import Testing
@testable import RIBs

/// KMP 스위트에 없는 이벤트 순서 계약. Router 문서 주석과 RIBs-iOS 순서를 기준으로 한다.
@MainActor
struct LifecycleOrderingTests {
    private let log = EventLog()

    private func node(_ name: String) -> RecordingRouter {
        RecordingRouter(name, log: log)
    }

    @Test func attach_activatesSubtreeInPreOrderBeforeLoad() {
        // Given: c는 didLoad에서 g를 붙이고, g는 didLoad에서 h를 붙인다
        let parent = node("p")
        let child = node("c")
        let grandChild = node("g")
        let greatGrandChild = node("h")
        child.onDidLoad = { child.attachChild(grandChild) }
        grandChild.onDidLoad = { grandChild.attachChild(greatGrandChild) }

        // When
        parent.attachChild(child)

        // Then
        #expect(log.entries == [
            "c.didBecomeActive", "c.didLoad",
            "g.didBecomeActive", "g.didLoad",
            "h.didBecomeActive", "h.didLoad",
        ])
    }

    @Test func reattach_activatesWholeKeptSubtreeInPreOrder() {
        // Given
        let parent = node("p")
        let child = node("c")
        let left = node("l")
        let leftLeaf = node("ll")
        let right = node("r")
        parent.attachChild(child)
        child.attachChild(left)
        left.attachChild(leftLeaf)
        child.attachChild(right)
        parent.detachChild(child)
        log.clear()

        // When
        parent.attachChild(child)

        // Then
        #expect(log.entries == ["c.didBecomeActive", "l.didBecomeActive", "ll.didBecomeActive", "r.didBecomeActive"])
    }

    @Test func detach_deactivatesInPreOrderThenRemoves() {
        // Given
        let parent = node("p")
        let child = node("c")
        let grandChild = node("g")
        parent.attachChild(child)
        child.attachChild(grandChild)
        let childrenSeenDuringResign = Box<Int?>(nil)
        child.interactor.onWillResignActive = { childrenSeenDuringResign.value = parent.children.count }
        log.clear()

        // When
        parent.detachChild(child)

        // Then
        #expect(log.entries == ["c.willResignActive", "g.willResignActive"])
        #expect(childrenSeenDuringResign.value == 1)
        #expect(parent.children.isEmpty)
    }

    @Test func attach_toInactiveParent_stillActivatesChild() {
        // Given: RIBs-iOS와 같이 부모 활성 여부와 무관하게 자식을 활성화한다
        let parent = node("p")
        let child = node("c")

        // When
        parent.attachChild(child)

        // Then
        #expect(!parent.interactor.isActive)
        #expect(child.interactor.isActive)
    }

    @Test func mountWithHost_showsThenActivatesThenLoads() {
        // Given
        let root = RecordingViewableRouter("root", log: log)
        let host = RecordingHost(log: log)

        // When
        let mount = root.mount(host: host)

        // Then
        #expect(log.entries == ["show(root)", "root.didBecomeActive", "root.didLoad"])
        #expect(mount.isMounted)
        mount.unmount()
    }

    @Test func unmountWithHost_deactivatesRootThenDetachesChildrenThenHides() {
        // Given
        let root = RecordingViewableRouter("root", log: log)
        let host = RecordingHost(log: log)
        let mount = root.mount(host: host)
        let child = node("c")
        root.attachChild(child)
        child.attachChild(node("g"))
        root.attachChild(node("d"))
        log.clear()

        // When
        mount.unmount()

        // Then
        #expect(log.entries == [
            "root.willResignActive",
            "c.willResignActive", "g.willResignActive",
            "d.willResignActive",
            "hide(root)",
        ])
        #expect(root.children.isEmpty)
        #expect(!mount.isMounted)
    }

    @Test func activeStreamObserver_runsBetweenWillResignActiveAndNextEvent() {
        // Given
        let parent = node("p")
        let child = node("c")
        parent.attachChild(child)
        let observation = child.interactor.observeActive { self.log.record("c.observer(\($0))") }
        log.clear()

        // When
        parent.detachChild(child)
        parent.attachChild(child)

        // Then
        #expect(log.entries == [
            "c.willResignActive", "c.observer(false)",
            "c.observer(true)", "c.didBecomeActive",
        ])
        observation.cancel()
    }
}
