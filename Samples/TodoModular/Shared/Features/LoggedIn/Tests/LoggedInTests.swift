import FeatureLoggedInInterface
import FeatureLoggedInTesting
import FeatureTodoDetailTesting
import FeatureTodoListTesting
import RIBs
import Testing
import TodoCore
import TodoCoreTesting

@testable import FeatureLoggedIn

/// LoggedIn 피처 단독 테스트. 자식(TodoList, TodoDetail)은 Testing 모듈의 가짜 Buildable이다.
@MainActor
final class LoggedInTests {
    private let clock = ManualClock()
    private let listBuilder = FakeTodoListBuildable()
    private let detailBuilder = FakeTodoDetailBuildable()
    private let views = FakeLoggedInViewFactory()
    private let listener = FakeLoggedInListener()
    private let dependency: FakeLoggedInDependency
    private let parent = TestParentRouter()
    private let router: any LoggedInRouting

    init() async {
        dependency = FakeLoggedInDependency(clock: clock, listBuilder: listBuilder, detailBuilder: detailBuilder)
        let builder = LoggedInBuilder(dependency: dependency, viewFactory: views)
        router = builder.build(listener: listener, userName: "carti")
        parent.attach(router)
        await runCurrent()
    }

    isolated deinit {
        parent.detach(router)
    }

    private var view: FakeLoggedInView { views.views.last! }

    @Test func showsUserNameAndListByDefault() {
        #expect(view.state?.userName == "carti")
        #expect(view.screen === listBuilder.views.last)
    }

    @Test func childrenShareOneStore() throws {
        let list = try #require(dependency.listDependencies.first)
        let detail = try #require(dependency.detailDependencies.first)

        #expect(list.todoStore === detail.todoStore)
    }

    @Test func selectingTodoOpensDetailAndBackClosesIt() throws {
        try #require(listBuilder.listeners.first).didSelectTodo(id: 2)
        let detail = try #require(detailBuilder.routers.last)
        #expect(detail.todoID == 2)
        #expect(view.screen === detail.viewControllable)

        #expect(router.handleBackPress())
        #expect(view.screen === listBuilder.views.last)
        #expect(!router.handleBackPress())
    }

    @Test func detailCloseRequestReturnsToList() throws {
        try #require(listBuilder.listeners.first).didSelectTodo(id: 1)

        try #require(detailBuilder.listeners.first).didRequestCloseDetail()

        #expect(view.screen === listBuilder.views.last)
    }

    /// 상세는 목록 위에 얹는다. 닫을 때 목록을 다시 붙이지 않는다(ADR-0030).
    @Test func detailIsShownAndHiddenWithoutReattachingList() throws {
        try #require(listBuilder.listeners.first).didSelectTodo(id: 2)
        #expect(view.calls == [.showList, .showDetail])

        try #require(detailBuilder.listeners.first).didRequestCloseDetail()
        #expect(view.calls == [.showList, .showDetail, .hideDetail])
    }

    @Test func userDismissalDetachesDetail() throws {
        try #require(listBuilder.listeners.first).didSelectTodo(id: 2)
        let detail = try #require(detailBuilder.routers.last)

        view.dismissDetailByUser()

        #expect(!detail.interactable.isActive)
        #expect((router as? LoggedInRouter)?.openDetailID == nil)
        #expect(view.screen === listBuilder.views.last)
        #expect(!router.handleBackPress())
    }

    @Test func userDismissalWithoutDetailDoesNothing() {
        view.dismissDetailByUser()

        #expect(view.calls == [.showList])
    }

    @Test func userDismissalIsIgnoredWhileInactive() throws {
        try #require(listBuilder.listeners.first).didSelectTodo(id: 2)
        let loggedIn = try #require(router as? LoggedInRouter)
        parent.detach(router)

        loggedIn.interactor.handle(.detailDismissedByUser)

        #expect(loggedIn.openDetailID == 2)
        parent.attach(router)  // deinit의 detach와 짝을 맞춘다.
    }

    @Test func missingTodoKeepsList() throws {
        detailBuilder.missingIDs = [7]

        try #require(listBuilder.listeners.first).didSelectTodo(id: 7)

        #expect(view.screen === listBuilder.views.last)
    }

    @Test func logoutTellsListener() {
        view.listener?.handle(.logoutTapped)

        #expect(listener.logoutRequests == 1)
    }

    /// 타이머의 첫 알림(0초)은 이미 그린 값이라 다시 그리지 않는다.
    @Test func firstTickDoesNotRenderAgain() {
        #expect(view.states == [LoggedInViewState(userName: "carti", sessionSeconds: 0)])
    }

    @Test func sessionTimerTicksUntilDetached() async {
        #expect(view.state == LoggedInViewState(userName: "carti", sessionSeconds: 0))

        await clock.advance(by: .milliseconds(2_500))
        #expect(view.state?.sessionSeconds == 2)

        parent.detach(router)
        await runCurrent()
        await clock.advance(by: .seconds(5))
        #expect(view.state?.sessionSeconds == 2)
        parent.attach(router)  // deinit의 detach와 짝을 맞춘다.
    }
}
