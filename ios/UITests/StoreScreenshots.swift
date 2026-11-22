import XCTest

/// The App Store's pictures, from the demo library: tabletop-kit's `store-screenshots.sh`.
/// Skipped unless the script names the folder to save into.
final class StoreScreenshots: XCTestCase {
    private var app: XCUIApplication!
    private var folder: URL!

    override func setUpWithError() throws {
        let path = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] ?? ""
        try XCTSkipIf(path.isEmpty, "Set SCREENSHOT_DIR to make the store screenshots.")
        folder = URL(fileURLWithPath: path)
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func testBoard() throws {
        launch("board")
        try save("1-board")
        guard TestDevice.isPhone else { return }
        app.showBoardCard()
        try save("2-card")
    }

    func testConditions() throws {
        launch("board")
        let strip = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS 'Goblin Warrior 3' AND NOT (label CONTAINS 'turn')"))
            .firstMatch
        XCTAssertTrue(strip.waitForExistence(timeout: 10))
        strip.press(forDuration: 1.2)
        let conditions = app.buttons["Conditions…"]
        XCTAssertTrue(conditions.waitForExistence(timeout: 5))
        conditions.tap()
        try save("3-conditions")
    }

    func testPlanner() throws {
        launch("planner")
        try save("4-encounter")
    }

    func testStarfinder() throws {
        launch("starfinder")
        try save("5-starfinder")
    }

    private func launch(_ demo: String) {
        XCUIDevice.shared.orientation = .portrait
        app.launchArguments = ["--demo", demo]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        sleep(2)
    }

    private func save(_ name: String) throws {
        sleep(1)
        let file = folder.appendingPathComponent("\(name).png")
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: file)
    }
}
