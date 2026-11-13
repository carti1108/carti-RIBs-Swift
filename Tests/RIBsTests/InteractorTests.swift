import Testing
@testable import RIBs

@MainActor
struct InteractorTests {
    private let log = EventLog()

    private func makeInteractor(_ name: String = "a") -> RecordingInteractor {
        RecordingInteractor(name: name, log: log)
    }

    @Test func isInactiveByDefault() {
        // Given / When
        let interactor = makeInteractor()

        // Then
        #expect(!interactor.isActive)
        #expect(log.entries.isEmpty)
    }

    @Test func activate_setsIsActiveAndCallsDidBecomeActive() {
        // Given
        let interactor = makeInteractor()

        // When
        interactor.activate()

        // Then
        #expect(interactor.isActive)
        #expect(log.entries == ["a.didBecomeActive"])
    }

    @Test func deactivate_clearsIsActiveAndCallsWillResignActive() {
        // Given
        let interactor = makeInteractor()
        interactor.activate()

        // When
        interactor.deactivate()

        // Then
        #expect(!interactor.isActive)
        #expect(log.entries == ["a.didBecomeActive", "a.willResignActive"])
    }

    @Test func activate_whenAlreadyActive_doesNotCallDidBecomeActiveAgain() {
        // Given
        let interactor = makeInteractor()
        interactor.activate()

        // When
        interactor.activate()

        // Then
        #expect(log.entries == ["a.didBecomeActive"])
    }

    @Test func deactivate_whenAlreadyInactive_doesNotCallWillResignActive() {
        // Given
        let interactor = makeInteractor()

        // When
        interactor.deactivate()
        interactor.activate()
        interactor.deactivate()
        interactor.deactivate()

        // Then
        #expect(log.entries == ["a.didBecomeActive", "a.willResignActive"])
    }

    @Test func activate_publishesIsActiveBeforeDidBecomeActive() {
        // Given
        let interactor = makeInteractor()
        let observation = interactor.observeActive { self.log.record("observer(\($0))") }
        let seenInCallback = Box<Bool?>(nil)
        interactor.onDidBecomeActive = { seenInCallback.value = interactor.isActive }
        log.clear()

        // When
        interactor.activate()

        // Then
        #expect(log.entries == ["observer(true)", "a.didBecomeActive"])
        #expect(seenInCallback.value == true)
        observation.cancel()
    }

    @Test func deactivate_callsWillResignActiveThenCancelsTasksThenPublishesInactive() async throws {
        // Given
        let interactor = makeInteractor()
        interactor.activate()
        let task = try interactor.task { await suspendUntilCancelled() }
        let observation = interactor.observeActive { self.log.record("observer(\($0))") }
        let stateInCallback = Box<(isActive: Bool, isCancelled: Bool)?>(nil)
        interactor.onWillResignActive = {
            stateInCallback.value = (interactor.isActive, task.isCancelled)
        }
        log.clear()

        // When
        interactor.deactivate()
        await task.value

        // Then
        #expect(log.entries == ["a.willResignActive", "observer(false)"])
        #expect(stateInCallback.value?.isActive == true)
        #expect(stateInCallback.value?.isCancelled == false)
        #expect(task.isCancelled)
        observation.cancel()
    }

    @Test func isActiveStream_emitsCurrentValueThenOnlyChanges() async {
        // Given
        let interactor = makeInteractor()
        let stream = interactor.isActiveStream

        // When
        interactor.activate()
        interactor.activate()
        interactor.deactivate()
        interactor.deactivate()
        interactor.activate()

        // Then
        #expect(await stream.take(4) == [false, true, false, true])
    }

    @Test func isActiveStream_lateSubscriberReceivesCurrentValueFirst() async {
        // Given
        let interactor = makeInteractor()
        interactor.activate()

        // When
        let stream = interactor.isActiveStream
        interactor.deactivate()

        // Then
        #expect(await stream.take(2) == [true, false])
    }

    @Test func observeActive_stopsDeliveringAfterCancel() {
        // Given
        let interactor = makeInteractor()
        let received = Box<[Bool]>([])
        let observation = interactor.observeActive { received.value.append($0) }

        // When
        interactor.activate()
        observation.cancel()
        observation.cancel()
        interactor.deactivate()

        // Then
        #expect(received.value == [false, true])
    }

    @Test func confineTo_emitsOnlyValuesConsumedWhileActive() async {
        // Given
        let interactor = makeInteractor()
        let (source, input) = AsyncStream<Int>.makeStream()
        let confined = source.confineTo(interactor)
        interactor.activate()

        // When / Then: 활성 중 값은 통과한다
        input.yield(1)
        #expect(await confined.take(1) == [1])

        // When: 비활성 중 값은 소비되며 버려진다
        interactor.deactivate()
        input.yield(2)
        await drainMainActor()
        interactor.activate()
        input.yield(3)
        input.finish()

        // Then: 다시 활성이 되어도 2를 재생하지 않는다(KMP와 다른 의도된 차이)
        #expect(await confined.take(10) == [3])
    }

    @Test func confineTo_valueBufferedWhileInactiveIsDeliveredIfActivatedBeforeRead() async {
        // Given
        let interactor = makeInteractor()
        let (source, input) = AsyncStream<Int>.makeStream()
        let confined = source.confineTo(interactor)

        // When: 비활성일 때 버퍼에 들어갔지만 내부 Task가 꺼내기 전에 활성화
        input.yield(1)
        interactor.activate()
        input.yield(2)
        input.finish()

        // Then: 꺼내는 시점에 활성이므로 둘 다 전달된다
        #expect(await confined.take(10) == [1, 2])
    }

    @Test func confineTo_finishesWhenSourceFinishes() async {
        // Given
        let interactor = makeInteractor()
        interactor.activate()
        let (source, input) = AsyncStream<Int>.makeStream()
        let confined = source.confineTo(interactor)

        // When
        input.finish()

        // Then
        #expect(await confined.take(1).isEmpty)
    }

    @Test func presentableInteractor_keepsPresenter() {
        // Given
        let view = FakeView(name: "v")

        // When
        let interactor = PresentableInteractor(presenter: view)

        // Then
        #expect(interactor.presenter === view)
        #expect(!interactor.isActive)
    }

    @Test func presenter_keepsViewController() {
        // Given
        let view = FakeView(name: "v")

        // When
        let presenter = Presenter(viewController: view)

        // Then
        #expect(presenter.viewController === view)
    }

    @Test func handleBackPress_defaultsToFalse() {
        #expect(Interactor().handleBackPress() == false)
    }
}
