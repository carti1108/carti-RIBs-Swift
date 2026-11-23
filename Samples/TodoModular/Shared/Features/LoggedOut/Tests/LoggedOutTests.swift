import FeatureLoggedOutInterface
import FeatureLoggedOutTesting
import RIBs
import Testing
import TodoCore
import TodoCoreTesting

@testable import FeatureLoggedOut

@MainActor
private final class Dependency: LoggedOutDependency {
    let authService: any AuthService
    init(authService: any AuthService) { self.authService = authService }
}

/// LoggedOut 피처 단독 테스트. 부모와 다른 피처 없이 돈다.
@MainActor
final class LoggedOutTests {
    private let auth = FakeAuthService()
    private let views = FakeLoggedOutViewFactory()
    private let listener = FakeLoggedOutListener()
    private let parent = TestParentRouter()
    private let router: any ViewableRouting

    init() {
        let builder = LoggedOutBuilder(dependency: Dependency(authService: auth), viewFactory: views)
        router = builder.build(listener: listener)
        parent.attach(router)
    }

    isolated deinit {
        parent.detach(router)
    }

    private var view: FakeLoggedOutView { views.views.last! }

    private func login(_ name: String) async {
        view.listener?.didTapLogin(rawName: name)
        await runCurrent()
    }

    @Test func blankNameShowsErrorWithoutCallingService() async {
        await login("   ")

        #expect(view.error == LoggedOutInteractor.emptyNameError)
        #expect(auth.requests.isEmpty)
    }

    @Test func trimsNameAndShowsLoadingUntilServiceResponds() async {
        await login("  carti ")

        #expect(auth.requests == ["carti"])
        #expect(view.isLoading)
    }

    @Test func successTellsListener() async {
        await login("carti")

        auth.respond(.success(userName: "carti"))
        await runCurrent()

        #expect(listener.loggedInNames == ["carti"])
        #expect(!view.isLoading)
    }

    @Test func failureShowsErrorAndStopsLoading() async {
        await login("carti")

        auth.respond(.failure(message: "서버 오류"))
        await runCurrent()

        #expect(view.error == "서버 오류")
        #expect(!view.isLoading)
        #expect(listener.loggedInNames.isEmpty)
    }

    @Test func tapWhileLoadingIsIgnored() async {
        await login("carti")

        await login("other")

        #expect(auth.requests == ["carti"])
    }

    @Test func detachCancelsRequestAndClearsListener() async {
        await login("carti")

        parent.detach(router)
        await runCurrent()

        #expect(auth.wasCancelled)
        #expect(view.listener == nil)
        parent.attach(router)  // deinit의 detach와 짝을 맞춘다.
    }
}
