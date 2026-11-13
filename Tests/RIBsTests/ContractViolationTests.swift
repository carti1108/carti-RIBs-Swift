import Testing
@testable import RIBs

#if os(macOS) || os(Linux)
/// 계약 위반은 `precondition`으로 프로세스를 끝낸다. 하위 프로세스에서 확인한다.
struct ContractViolationTests {
    @Test func attachingSameChildTwice_terminatesProcess() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                let parent = Router(interactor: Interactor())
                let child = Router(interactor: Interactor())
                parent.attachChild(child)
                parent.attachChild(child)
            }
        }
    }

    @Test func detachingNonChild_terminatesProcess() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                let parent = Router(interactor: Interactor())
                parent.detachChild(Router(interactor: Interactor()))
            }
        }
    }

    @Test func launchingTwice_terminatesProcess() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                let root = LaunchRouter(interactor: Interactor(), viewController: FakeView(name: "root"))
                let host = RecordingHost()
                root.launch(from: host)
                root.launch(from: host)
            }
        }
    }

    @Test func mountingAlreadyActiveRouter_terminatesProcess() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                let router = Router(interactor: Interactor())
                router.interactable.activate()
                _ = router.mount()
            }
        }
    }

    @Test func routerWithNonInteractableInteractor_terminatesProcess() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                _ = Router(interactor: "not an interactor")
            }
        }
    }

    @Test func ribStateWithNonFiniteDouble_terminatesProcess() async {
        await #expect(processExitsWith: .failure) {
            _ = RibState(["nan": .list([.double(.nan)])])
        }
    }

    @Test func componentizedBuilderWithoutOverride_terminatesProcess() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                let builder = SimpleComponentizedBuilder<EmptyComponent, Router<Interactor>> { EmptyComponent() }
                _ = builder.build()
            }
        }
    }
}
#endif
