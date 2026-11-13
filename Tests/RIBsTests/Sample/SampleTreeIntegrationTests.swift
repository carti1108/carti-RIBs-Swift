import Testing
@testable import RIBs

@MainActor
struct SampleTreeIntegrationTests {
    private let host = RecordingHost()

    private func launchedRoot() -> RootRouter {
        let root = RootBuilder(dependency: EmptyComponent()).build()
        root.launch(from: host)
        return root
    }

    private func child<T>(of root: RootRouter, as type: T.Type = T.self) throws -> T {
        let matches = root.children.compactMap { $0 as? T }
        try #require(matches.count == 1)
        return matches[0]
    }

    @Test func launch_showsRootAndRoutesToLoggedOut() throws {
        // Given / When
        let root = launchedRoot()

        // Then
        #expect(host.log.entries == ["show(root)"])
        #expect(root.children.count == 1)
        _ = try child(of: root, as: LoggedOutRouter.self)
    }

    @Test func loginIntent_replacesLoggedOutWithLoggedIn() throws {
        // Given
        let root = launchedRoot()
        let loggedOut = try child(of: root, as: LoggedOutRouter.self)

        // When
        loggedOut.viewController.didTapLogin("  carti  ")

        // Then
        let loggedIn = try child(of: root, as: LoggedInRouter.self)
        #expect(root.children.count == 1)
        #expect(loggedIn.interactor.userName == "carti")
        #expect(!loggedOut.interactor.isActive)
        #expect(loggedIn.interactor.heartbeat.isStarted)
        let heartbeatTask = try #require(loggedIn.interactor.heartbeat.runningTask)
        #expect(!heartbeatTask.isCancelled)
    }

    @Test func blankName_isRejectedByPresenterWithoutRouting() throws {
        // Given
        let root = launchedRoot()
        let presenter = try child(of: root, as: LoggedOutRouter.self).viewController

        // When
        presenter.didTapLogin("   ")

        // Then
        #expect(presenter.errorMessage == "이름을 입력하세요")
        #expect(root.children.count == 1)
        _ = try child(of: root, as: LoggedOutRouter.self)
    }

    @Test func childrenShareSessionStoreFromRootComponent() throws {
        // Given
        let root = launchedRoot()
        let loggedOut = try child(of: root, as: LoggedOutRouter.self)
        loggedOut.viewController.didTapLogin("carti")
        let loggedIn = try child(of: root, as: LoggedInRouter.self)

        // When / Then
        #expect(loggedOut.interactor.sessionStore === loggedIn.interactor.sessionStore)
        #expect(loggedIn.interactor.sessionStore.user == "carti")

        loggedIn.interactor.logout()
        #expect(loggedIn.interactor.sessionStore.user == nil)
    }

    @Test func logout_stopsWorkerAndReturnsToLoggedOut() async throws {
        // Given
        let root = launchedRoot()
        try child(of: root, as: LoggedOutRouter.self).viewController.didTapLogin("carti")
        let loggedIn = try child(of: root, as: LoggedInRouter.self)
        let heartbeat = loggedIn.interactor.heartbeat
        let heartbeatTask = try #require(heartbeat.runningTask)

        // When
        loggedIn.interactor.logout()
        await heartbeatTask.value

        // Then
        #expect(heartbeat.stopped)
        #expect(heartbeatTask.isCancelled)
        #expect(!loggedIn.interactor.isActive)
        _ = try child(of: root, as: LoggedOutRouter.self)
    }

    @Test func shutdown_detachesWholeTreeAndHidesRoot() throws {
        // Given
        let root = launchedRoot()
        try child(of: root, as: LoggedOutRouter.self).viewController.didTapLogin("carti")
        let loggedIn = try child(of: root, as: LoggedInRouter.self)

        // When
        root.shutdown()

        // Then
        #expect(!root.interactable.isActive)
        #expect(!loggedIn.interactor.isActive)
        #expect(loggedIn.interactor.heartbeat.stopped)
        #expect(root.children.isEmpty)
        #expect(host.log.entries == ["show(root)", "hide(root)"])
    }

    @Test func relaunchAfterShutdown_startsFreshTree() throws {
        // Given
        let root = RootBuilder(dependency: EmptyComponent()).build()
        root.launch(from: host)
        try child(of: root, as: LoggedOutRouter.self).viewController.didTapLogin("carti")
        root.shutdown()

        // When
        root.launch(from: host)

        // Then
        #expect(root.children.count == 1)
        _ = try child(of: root, as: LoggedOutRouter.self)
    }
}
