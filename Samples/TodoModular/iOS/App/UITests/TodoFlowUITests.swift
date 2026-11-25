import XCTest

/// µFeature로 나눈 RIB 트리(TodoAppRoot)가 SwiftUI 화면을 실제로 전환하는지 확인한다.
final class TodoFlowUITests: XCTestCase {
    private let timeout: TimeInterval = 5
    /// XCUITest 스냅샷이 1초 가까이 걸리므로, 로딩 상태를 확인할 수 있게 응답을 늦춘다.
    private let loginDelayMillis = 3000
    private var app: XCUIApplication!

    @MainActor
    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-loginDelayMillis", String(loginDelayMillis)]
        app.launch()
    }

    @MainActor
    func testBlankNameShowsError() {
        app.buttons["loginButton"].tap()

        XCTAssertTrue(app.staticTexts["errorLabel"].waitForExistence(timeout: timeout))
    }

    @MainActor
    func testLoginThenLogoutReturnsToEmptyLoggedOutScreen() {
        let field = app.textFields["nameField"]
        XCTAssertTrue(field.waitForExistence(timeout: timeout))
        field.tap()
        field.typeText("  carti ")
        app.buttons["loginButton"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["loadingIndicator"].waitForExistence(timeout: timeout))
        XCTAssertFalse(app.buttons["loginButton"].isEnabled)

        let welcome = app.staticTexts["welcomeLabel"]
        XCTAssertTrue(welcome.waitForExistence(timeout: timeout))
        XCTAssertEqual(welcome.label, "carti님, 환영합니다")

        app.buttons["logoutButton"].tap()

        XCTAssertTrue(field.waitForExistence(timeout: timeout))
        XCTAssertEqual(field.value as? String, "이름")
        XCTAssertFalse(app.staticTexts["errorLabel"].exists)
    }

    @MainActor
    func testFailedLoginShowsServerErrorAndAllowsRetry() {
        let field = app.textFields["nameField"]
        XCTAssertTrue(field.waitForExistence(timeout: timeout))
        field.tap()
        field.typeText("fail")
        app.buttons["loginButton"].tap()

        let error = app.staticTexts["errorLabel"]
        XCTAssertTrue(error.waitForExistence(timeout: timeout))
        XCTAssertEqual(error.label, "로그인에 실패했습니다")
        XCTAssertFalse(app.descendants(matching: .any)["loadingIndicator"].exists)
        XCTAssertTrue(app.buttons["loginButton"].isEnabled)
    }

    @MainActor
    func testTodoDetailTogglesDoneAndBackReturnsToList() {
        let field = app.textFields["nameField"]
        XCTAssertTrue(field.waitForExistence(timeout: timeout))
        field.tap()
        field.typeText("carti")
        app.buttons["loginButton"].tap()

        let row = app.buttons["todoRow-1"]
        XCTAssertTrue(row.waitForExistence(timeout: timeout + Double(loginDelayMillis) / 1000))
        row.tap()
        XCTAssertEqual(app.staticTexts["detailTitle"].label, "우유 사기")
        app.buttons["toggleDoneButton"].tap()
        app.buttons["backButton"].tap()

        XCTAssertTrue(row.waitForExistence(timeout: timeout))
        XCTAssertEqual(row.label, "✓ 우유 사기")
        XCTAssertFalse(app.staticTexts["detailTitle"].exists)
    }

    /// 화면 왼쪽 끝에서 미는 뒤로 가기로 상세를 닫아도 RIB 트리가 따라온다(ADR-0030).
    /// 닫힌 뒤 다른 할 일을 열 수 있어야 한다. 트리에 상세가 남아 있으면 두 번째 상세가 열리지 않는다.
    @MainActor
    func testSwipeBackClosesDetailAndKeepsTreeInSync() {
        let field = app.textFields["nameField"]
        XCTAssertTrue(field.waitForExistence(timeout: timeout))
        field.tap()
        field.typeText("carti")
        app.buttons["loginButton"].tap()

        let row = app.buttons["todoRow-1"]
        XCTAssertTrue(row.waitForExistence(timeout: timeout + Double(loginDelayMillis) / 1000))
        row.tap()
        let title = app.staticTexts["detailTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: timeout))

        let leftEdge = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
        leftEdge.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))

        XCTAssertTrue(row.waitForExistence(timeout: timeout))
        XCTAssertFalse(title.exists)

        let secondRow = app.buttons["todoRow-2"]
        secondRow.tap()
        XCTAssertTrue(title.waitForExistence(timeout: timeout))
        XCTAssertNotEqual(title.label, "우유 사기")
    }
}
