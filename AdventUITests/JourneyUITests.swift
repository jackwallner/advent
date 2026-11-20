import XCTest

@MainActor
final class JourneyUITests: XCTestCase {
    override func setUp() async throws { continueAfterFailure = false }

    private func launch(day: Int) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-DebugDay", "\(day)"]
        app.launch()
        return app
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func makeCalendar(_ app: XCUIApplication, _ cats: [String], budget: String) {
        XCTAssertTrue(app.buttons["make"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["make"].isEnabled, "needs a category first")
        for c in cats { app.buttons["cat-\(c)"].tap() }
        app.buttons["budget-\(budget)"].tap()
        app.buttons["make"].tap()
        XCTAssertTrue(app.buttons["door-1"].waitForExistence(timeout: 10))
    }

    func testOpenTodaysDoorAndRateIt() {
        let app = launch(day: 5)
        snap(app, "01-setup")
        makeCalendar(app, ["family", "food", "humor"], budget: "low")
        snap(app, "02-board")

        app.buttons["door-5"].tap()
        let title = app.staticTexts["day-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        app.buttons["star-4"].tap()
        XCTAssertTrue(app.buttons["star-4"].isSelected)
        snap(app, "03-door")
        app.buttons["Close"].firstMatch.tap()

        let door = app.buttons["door-5"]
        XCTAssertTrue(door.waitForExistence(timeout: 5))
        XCTAssertTrue(door.label.hasPrefix("Day 5, "), door.label)
        snap(app, "04-board-opened")

        // Relaunch keeps the opened door and rating.
        app.terminate()
        let again = XCUIApplication()
        again.launchArguments = ["-DebugDay", "5"]
        again.launch()
        XCTAssertTrue(again.buttons["door-5"].waitForExistence(timeout: 10))
        XCTAssertTrue(again.buttons["door-5"].label.hasPrefix("Day 5, "))
    }

    func testFutureDoorStaysLocked() {
        let app = launch(day: 3)
        makeCalendar(app, ["puzzles"], budget: "none")
        app.buttons["door-9"].tap()
        XCTAssertTrue(app.staticTexts["Opens December 9"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["day-title"].exists)
        XCTAssertEqual(app.buttons["door-9"].label, "Day 9, opens December 9")
    }

    func testCountdownBeforeDecember() {
        let app = launch(day: 0)
        makeCalendar(app, ["selfcare", "books", "music"], budget: "medium")
        snap(app, "05-countdown")
        app.buttons["door-1"].tap()
        XCTAssertTrue(app.staticTexts["Opens December 1"].waitForExistence(timeout: 3))
    }

    func testMakeOneForSomeone() {
        let app = launch(day: 7)
        makeCalendar(app, ["fitness"], budget: "none")
        app.buttons["gift"].tap()
        XCTAssertTrue(app.buttons["make"].waitForExistence(timeout: 5))
        app.buttons["cat-family"].tap()
        app.buttons["cat-puzzles"].tap()
        app.buttons["budget-high"].tap()
        app.textFields["to"].tap()
        app.textFields["to"].typeText("Hazel")
        app.textFields["from"].tap()
        app.textFields["from"].typeText("Grandma")
        snap(app, "06-gift-setup")
        app.buttons["make"].tap()
        XCTAssertTrue(app.buttons["send"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["For Hazel"].exists)
        snap(app, "07-gift-share")
        app.buttons["preview"].tap()
        XCTAssertTrue(app.staticTexts["from Grandma"].waitForExistence(timeout: 5))
        app.buttons["door-24"].tap()
        XCTAssertTrue(app.staticTexts["day-title"].waitForExistence(timeout: 5))
        snap(app, "08-gift-preview-door")
    }
}
