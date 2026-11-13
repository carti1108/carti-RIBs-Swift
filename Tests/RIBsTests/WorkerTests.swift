import Testing
@testable import RIBs

@MainActor
struct WorkerTests {
    private func expectCounts(
        _ worker: CountingWorker, started: Bool, didStart: Int, didStop: Int,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(worker.isStarted == started, sourceLocation: sourceLocation)
        #expect(worker.didStartCount == didStart, sourceLocation: sourceLocation)
        #expect(worker.didStopCount == didStop, sourceLocation: sourceLocation)
    }

    @Test func didStart_followsInteractorActivityOnceOnly() {
        // Given
        let interactor = Interactor()
        let worker = CountingWorker()
        expectCounts(worker, started: false, didStart: 0, didStop: 0)

        // When / Then
        worker.start(interactor)
        expectCounts(worker, started: true, didStart: 0, didStop: 0)

        interactor.activate()
        expectCounts(worker, started: true, didStart: 1, didStop: 0)

        interactor.deactivate()
        expectCounts(worker, started: true, didStart: 1, didStop: 1)

        worker.start(interactor)
        expectCounts(worker, started: true, didStart: 1, didStop: 1)

        interactor.activate()
        expectCounts(worker, started: true, didStart: 2, didStop: 1)

        worker.stop()
        expectCounts(worker, started: false, didStart: 2, didStop: 2)

        worker.stop()
        expectCounts(worker, started: false, didStart: 2, didStop: 2)
    }

    @Test func start_onActiveInteractor_callsDidStartImmediately() {
        // Given
        let interactor = Interactor()
        interactor.activate()
        let worker = CountingWorker()

        // When
        worker.start(interactor)

        // Then
        expectCounts(worker, started: true, didStart: 1, didStop: 0)
    }

    @Test func stop_detachesFromInteractor() {
        // Given
        let interactor = Interactor()
        let worker = CountingWorker()
        worker.start(interactor)
        worker.stop()

        // When
        interactor.activate()
        interactor.deactivate()

        // Then
        expectCounts(worker, started: false, didStart: 0, didStop: 0)
    }

    @Test func stop_whileInteractorInactive_doesNotCallDidStop() {
        // Given
        let interactor = Interactor()
        let worker = CountingWorker()
        worker.start(interactor)

        // When
        worker.stop()

        // Then
        expectCounts(worker, started: false, didStart: 0, didStop: 0)
    }

    @Test func start_whileStarted_ignoresSecondInteractor() {
        // Given
        let first = Interactor()
        let second = Interactor()
        let worker = CountingWorker()
        worker.start(first)

        // When
        worker.start(second)
        second.activate()

        // Then
        expectCounts(worker, started: true, didStart: 0, didStop: 0)
        first.activate()
        expectCounts(worker, started: true, didStart: 1, didStop: 0)
    }

    @Test func restartAfterStop_bindsToNewInteractor() {
        // Given
        let first = Interactor()
        let second = Interactor()
        let worker = CountingWorker()
        worker.start(first)
        worker.stop()

        // When
        worker.start(second)
        first.activate()
        second.activate()

        // Then
        expectCounts(worker, started: true, didStart: 1, didStop: 0)
    }

    @Test func isStartedStream_followsStartAndStop() async {
        // Given
        let worker = CountingWorker()
        let stream = worker.isStartedStream

        // When
        worker.start(Interactor())
        worker.start(Interactor())
        worker.stop()

        // Then
        #expect(await stream.take(3) == [false, true, false])
    }

    @Test func task_isCancelledWhenInteractorDeactivates() async throws {
        // Given
        let interactor = Interactor()
        let worker = CountingWorker()
        worker.launchesTaskOnStart = true
        worker.start(interactor)
        interactor.activate()
        let task = try #require(worker.startedTask)

        // When
        interactor.deactivate()
        await task.value

        // Then
        #expect(task.isCancelled)
        #expect(worker.isStarted)
        #expect(throws: LifecycleError.ended(owner: "CountingWorker")) { try worker.task {} }
    }

    @Test func task_isCancelledOnStop() async throws {
        // Given
        let interactor = Interactor()
        interactor.activate()
        let worker = CountingWorker()
        worker.launchesTaskOnStart = true
        worker.start(interactor)
        let task = try #require(worker.startedTask)

        // When
        worker.stop()
        await task.value

        // Then
        #expect(task.isCancelled)
        #expect(interactor.isActive)
    }

    @Test func didStop_runsAfterInteractorWillResignActive() {
        // Given
        let log = EventLog()
        let interactor = RecordingInteractor(name: "i", log: log)
        let worker = CountingWorker()
        worker.log = log
        worker.start(interactor)

        // When
        interactor.activate()
        interactor.deactivate()

        // Then
        #expect(log.entries == ["worker.didStart", "i.didBecomeActive", "i.willResignActive", "worker.didStop"])
    }
}
