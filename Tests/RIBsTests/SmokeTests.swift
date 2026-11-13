import Testing
@testable import RIBs

@MainActor
struct SmokeTests {
    private final class SampleView: ViewControllable {}

    private final class SampleHost: ViewHost {
        var shown: [SampleView] = []
        func show(_ view: SampleView) { shown.append(view) }
        func hide(_ view: SampleView) { shown.removeAll { $0 === view } }
    }

    @Test func launchActivatesTreeAndShutdownDeactivates() throws {
        // Given
        let root = LaunchRouter(interactor: Interactor(), viewController: SampleView())
        let child = Router(interactor: Interactor())
        let host = SampleHost()

        // When
        root.launch(from: host)
        root.attachChild(child)

        // Then
        #expect(root.interactable.isActive)
        #expect(child.interactable.isActive && child.isLoaded)
        #expect(host.shown.count == 1)

        root.shutdown()
        #expect(!root.interactable.isActive)
        #expect(!child.interactable.isActive)
        #expect(host.shown.isEmpty)
    }

    @Test func ribStateRoundTripsThroughString() throws {
        let state = RibState(["a": .int(1), "b": .list([.double(2), .string("x\"\n"), .null])])
        let decoded = try RibState(decoding: state.encodedString())
        #expect(decoded == state)
    }

    @Test func interactorTaskIsCancelledOnDeactivate() async throws {
        let interactor = Interactor()
        #expect(throws: LifecycleError.notStarted(owner: "Interactor")) { try interactor.task {} }
        interactor.activate()
        let task = try interactor.task { try? await Task.sleep(for: .seconds(60)) }
        interactor.deactivate()
        await task.value
        #expect(task.isCancelled)
        #expect(throws: LifecycleError.ended(owner: "Interactor")) { try interactor.task {} }
    }
}
