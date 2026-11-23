import Testing
import TodoCore
import TodoCoreTesting

@MainActor
struct DelayedAuthServiceTests {
    @Test func failsOnlyForFailingNameAfterDelay() async throws {
        let clock = ManualClock()
        let service = DelayedAuthService(delay: .milliseconds(800), clock: clock)
        var results: [AuthResult] = []

        let task = Task {
            results.append(try await service.signIn(userName: "carti"))
            results.append(try await service.signIn(userName: DelayedAuthService.failingName))
        }
        await runCurrent()
        #expect(results.isEmpty)
        await clock.advance(by: .milliseconds(1_600))
        try await task.value

        #expect(results == [.success(userName: "carti"), .failure(message: DelayedAuthService.failureMessage)])
    }

    @Test func storeTogglesAndRestoresDoneIDs() {
        let store = TodoStore()

        store.toggle(2)
        #expect(store.doneIDs == [2])

        store.restoreDone([1, 3])
        #expect(store.doneIDs == [1, 3])
    }
}
