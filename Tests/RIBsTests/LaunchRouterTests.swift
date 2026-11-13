import Testing
@testable import RIBs

@MainActor
struct LaunchRouterTests {
    private let log = EventLog()

    @Test func launch_showsViewThenActivatesThenLoads() {
        // Given
        let root = RecordingLaunchRouter("root", log: log)
        let host = RecordingHost(log: log)

        // When
        root.launch(from: host)

        // Then
        #expect(log.entries == ["show(root)", "root.didBecomeActive", "root.didLoad"])
        #expect(root.tag == "RecordingLaunchRouter")
    }

    @Test func shutdown_deactivatesWholeTreeThenHidesView() {
        // Given
        let root = RecordingLaunchRouter("root", log: log)
        let host = RecordingHost(log: log)
        root.launch(from: host)
        let child = RecordingRouter("c", log: log)
        root.attachChild(child)
        log.clear()

        // When
        root.shutdown()

        // Then
        #expect(log.entries == ["root.willResignActive", "c.willResignActive", "hide(root)"])
        #expect(root.children.isEmpty)
        #expect(!root.interactor.isActive)
    }

    @Test func shutdown_beforeLaunchOrTwice_isNoOp() {
        // Given
        let root = RecordingLaunchRouter("root", log: log)
        let host = RecordingHost(log: log)

        // When
        root.shutdown()
        root.launch(from: host)
        root.shutdown()
        root.shutdown()

        // Then
        #expect(log.entries == ["show(root)", "root.didBecomeActive", "root.didLoad", "root.willResignActive", "hide(root)"])
    }

    @Test func relaunchAfterShutdown_reactivatesAndReloads() {
        // Given
        let root = RecordingLaunchRouter("root", log: log)
        let host = RecordingHost(log: log)
        root.launch(from: host)
        root.shutdown()
        log.clear()

        // When
        root.launch(from: host)

        // Then
        #expect(log.entries == ["show(root)", "root.didBecomeActive", "root.didLoad"])
        root.shutdown()
    }

    @Test func launch_withSavedState_restoresRootInteractor() {
        // Given
        let original = RecordingLaunchRouter("root", log: log)
        original.interactor.valueToSave = "saved"
        let saved = original.saveInstanceState()
        let root = RecordingLaunchRouter("root", log: log)

        // When
        root.launch(from: RecordingHost(), savedInstanceState: saved)

        // Then
        #expect(root.interactor.restoredValue == "saved")
        root.shutdown()
    }

    @Test func mount_embedsSubtreeIntoNonRibHost() {
        // Given
        let router = RecordingViewableRouter("embedded", log: log)
        let host = RecordingHost(log: log)

        // When
        let mount = router.mount(host: host)

        // Then
        #expect(mount.isMounted)
        #expect(router.interactor.isActive && router.isLoaded)
        #expect(log.entries.first == "show(embedded)")
        mount.unmount()
    }

    @Test func unmount_isIdempotent() {
        // Given
        let router = RecordingViewableRouter("embedded", log: log)
        let mount = router.mount(host: RecordingHost(log: log))
        log.clear()

        // When
        mount.unmount()
        mount.unmount()

        // Then
        #expect(log.entries == ["embedded.willResignActive", "hide(embedded)"])
        #expect(!mount.isMounted)
    }

    @Test func mount_routerWithoutView_activatesAndLoadsOnly() {
        // Given
        let router = RecordingRouter("headless", log: log)

        // When
        let mount = router.mount()

        // Then
        #expect(log.entries == ["headless.didBecomeActive", "headless.didLoad"])
        mount.unmount()
        #expect(!router.interactor.isActive)
    }

    @Test func remountAfterUnmount_activatesAndReloads() {
        // Given
        let router = RecordingRouter("headless", log: log)
        router.mount().unmount()
        log.clear()

        // When
        let mount = router.mount()

        // Then
        #expect(log.entries == ["headless.didBecomeActive", "headless.didLoad"])
        mount.unmount()
    }
}
