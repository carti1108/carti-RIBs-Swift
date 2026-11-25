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
        view.listener?.handle(.loginTapped(rawName: name))
        await runCurrent()
    }

    @Test func rendersIdleStateWhenAttached() {
        #expect(view.states == [LoggedOutViewState()])
    }

    @Test func blankNameShowsErrorWithoutCallingService() async {
        await login("   ")

        #expect(view.state?.errorMessage == LoggedOutInteractor.emptyNameError)
        #expect(auth.requests.isEmpty)
    }

    @Test func trimsNameAndShowsLoadingUntilServiceResponds() async {
        await login("  carti ")

        #expect(auth.requests == ["carti"])
        #expect(view.state == LoggedOutViewState(errorMessage: nil, isLoading: true))
    }

    @Test func successTellsListener() async {
        await login("carti")

        auth.respond(.success(userName: "carti"))
        await runCurrent()

        #expect(listener.loggedInNames == ["carti"])
        #expect(view.state?.isLoading == false)
    }

    /// 오류와 로딩 해제가 따로 그려지면 중간 상태가 화면에 나온다.
    @Test func failureRendersErrorAndLoadingOffInOneState() async {
        await login("carti")
        let rendersBeforeResponse = view.states.count

        auth.respond(.failure(message: "서버 오류"))
        await runCurrent()

        #expect(view.states.count == rendersBeforeResponse + 1)
        #expect(view.state == LoggedOutViewState(errorMessage: "서버 오류", isLoading: false))
        #expect(listener.loggedInNames.isEmpty)
    }

    @Test func tapWhileLoadingIsIgnored() async {
        await login("carti")

        await login("other")

        #expect(auth.requests == ["carti"])
    }

    /// 뷰가 버튼을 막지 않아 빈 이름이 들어와도 진행 중인 요청의 로딩 표시는 남아야 한다.
    @Test func blankNameWhileLoadingKeepsLoading() async {
        await login("carti")

        await login("   ")

        #expect(view.state == LoggedOutViewState(errorMessage: LoggedOutInteractor.emptyNameError, isLoading: true))
    }

    @Test func detachCancelsRequestAndClearsListener() async {
        await login("carti")

        parent.detach(router)
        await runCurrent()

        #expect(auth.wasCancelled)
        #expect(view.listener == nil)
        parent.attach(router)  // deinit의 detach와 짝을 맞춘다.
        #expect(view.state?.isLoading == false)
    }
}
