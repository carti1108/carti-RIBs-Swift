import XCTest

/// 공유 코드(LoginShared)의 RIB 트리가 SwiftUI 화면을 실제로 전환하는지 확인한다.
final class LoginFlowUITests: XCTestCase {
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
}
