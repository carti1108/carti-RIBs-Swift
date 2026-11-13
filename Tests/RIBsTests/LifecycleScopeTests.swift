import Testing
@testable import RIBs

/// `Interactor.task(_:)`의 활성 구간 규칙. KMP `LifecycleScopeTest`의 Swift 대응.
/// 의도된 차이: 구간 밖 호출은 조용히 무시하지 않고 `LifecycleError`를 던진다.
@MainActor
struct LifecycleScopeTests {
    private let log = EventLog()

    @Test func task_beforeActivate_throwsNotStartedNamedAfterSubclass() {
        // Given
        let interactor = RecordingInteractor(name: "a", log: log)

        // When / Then
        #expect(throws: LifecycleError.notStarted(owner: "RecordingInteractor")) {
            try interactor.task {}
        }
    }

    @Test func task_afterDeactivate_throwsEnded() {
        // Given
        let interactor = RecordingInteractor(name: "a", log: log)
        interactor.activate()
        interactor.deactivate()

        // When / Then
        #expect(throws: LifecycleError.ended(owner: "RecordingInteractor")) {
            try interactor.task {}
        }
    }

    @Test func task_afterReactivation_runsAgain() async throws {
        // Given
        let interactor = RecordingInteractor(name: "a", log: log)
        interactor.activate()
        interactor.deactivate()
        interactor.activate()
        let ran = Box(false)

        // When
        let task = try interactor.task { ran.value = true }
        await task.value

        // Then
        #expect(ran.value)
        #expect(!task.isCancelled)
    }

    @Test func task_runsOnMainActorWhileActive() async throws {
        // Given
        let interactor = RecordingInteractor(name: "a", log: log)
        interactor.activate()
        let seenActive = Box<Bool?>(nil)

        // When
        let task = try interactor.task {
            MainActor.assertIsolated()
            seenActive.value = interactor.isActive
        }
        await task.value

        // Then
        #expect(seenActive.value == true)
    }

    @Test func deactivate_cancelsEveryRunningTask() async throws {
        // Given
        let interactor = RecordingInteractor(name: "a", log: log)
        interactor.activate()
        let first = try interactor.task { await suspendUntilCancelled() }
        let second = try interactor.task { await suspendUntilCancelled() }

        // When
        interactor.deactivate()
        await first.value
        await second.value

        // Then
        #expect(first.isCancelled && second.isCancelled)
    }

    @Test func task_startedInWillResignActive_isCancelledRightAfter() async throws {
        // Given
        let interactor = RecordingInteractor(name: "a", log: log)
        interactor.activate()
        let lateTask = Box<Task<Void, Never>?>(nil)
        interactor.onWillResignActive = {
            lateTask.value = try? interactor.task { await suspendUntilCancelled() }
        }

        // When
        interactor.deactivate()
        let task = try #require(lateTask.value)
        await task.value

        // Then
        #expect(task.isCancelled)
    }

    @Test func task_seesCancellationAfterDeactivate() async throws {
        // Given
        let interactor = RecordingInteractor(name: "a", log: log)
        interactor.activate()
        let observedCancellation = Box(false)
        let task = try interactor.task {
            await suspendUntilCancelled()
            observedCancellation.value = Task.isCancelled
        }

        // When
        interactor.deactivate()
        await task.value

        // Then
        #expect(observedCancellation.value)
    }

    @Test func workerTask_outsideStartedInterval_throws() {
        // Given
        let worker = CountingWorker()

        // When / Then
        #expect(throws: LifecycleError.notStarted(owner: "CountingWorker")) { try worker.task {} }
    }
}
