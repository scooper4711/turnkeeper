import XCTest

/// Walks the demo library and saves a picture of each screen, for checking layouts on a device size by eye:
/// `scripts/screenshot-tour.sh`. Skipped unless `SCREENSHOT_DIR` names the folder to save into.
final class ScreenshotTour: XCTestCase {
    private var app: XCUIApplication!
    private var folder: URL!

    override func setUpWithError() throws {
        let path = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] ?? ""
        try XCTSkipIf(path.isEmpty, "Set SCREENSHOT_DIR to run the screenshot tour.")
        folder = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        continueAfterFailure = true
        app = XCUIApplication()
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    func testBoard() {
        launch("board")
        save("board")
        tap(app.buttons["Fight"])
        save("board-fight-menu")
        dismissMenu()
        tapStrip("Goblin Warrior 1")
        save("board-strip-tapped")
        if app.buttons["Notes"].waitForExistence(timeout: 2) {
            app.buttons["Notes"].tap()
            save("board-card-notes")
        }
        tap(app.buttons["Done"])
        tap(app.buttons.matching(NSPredicate(format: "label CONTAINS '6/6'")).firstMatch)
        save("board-hit-points")
        closeSheet()
        openMenu(ofStrip: "Goblin Warrior 3")
        save("board-strip-menu")
        tap(app.buttons["Conditions…"])
        save("board-conditions")
        tap(app.buttons["Done"])
        tap(app.buttons["Next"])
        save("board-next")
        tap(app.buttons["Got It"])
        tap(app.switches["Player Screen"])
        save("board-player-screen")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        save("board-landscape")
        tapStrip("Goblin Warrior 2")
        save("board-landscape-strip-tapped")
    }

    func testSetup() {
        launch("setup")
        save("setup")
        openMenu(ofStrip: "Goblin Warrior 1")
        tap(app.buttons["Initiative…"])
        save("setup-initiative-pad")
        closeSheet()
        let talk = app.otherElements["Hold to Say Initiative"].firstMatch
        let held = talk.exists ? talk : app.descendants(matching: .any)["Hold to Say Initiative"].firstMatch
        if held.waitForExistence(timeout: 3) { held.press(forDuration: 1.5) }
        save("setup-after-voice")
        tap(app.buttons["Begin Combat"])
        save("setup-begin-warning")
        tap(app.buttons["Go Back"])
        XCUIDevice.shared.orientation = .landscapeLeft
        save("setup-landscape")
    }

    func testStarfinder() {
        launch("starfinder")
        save("starfinder-board")
        tapStrip("Akata")
        save("starfinder-card")
    }

    func testEncounter() {
        launch("planner")
        save("planner-encounter")
        tap(app.buttons["Card"].firstMatch)
        save("planner-creature-card")
        tap(app.buttons["Done"])
        app.swipeUp()
        save("planner-encounter-creatures")
        scroll(to: app.buttons["Add Creature…"])
        tap(app.buttons["Add Creature…"])
        save("planner-bestiary")
        tap(app.buttons["Done"])
        scroll(to: app.buttons["Add Custom Creature…"])
        tap(app.buttons["Add Custom Creature…"])
        save("planner-custom-creature")
        tap(app.buttons["Cancel"])
        scroll(to: app.buttons["Add Event…"])
        save("planner-encounter-events")
        tap(app.buttons["Add Event…"])
        save("planner-event-editor")
        tap(app.buttons["Cancel"])
    }

    func testLibrary() {
        launch("planner")
        back()
        save("planner-campaign")
        tap(app.staticTexts["#7-99: The Goblin Docks"])
        save("planner-scenario")
        back()
        tap(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Friday table'")).firstMatch)
        save("planner-party")
        back()
        tap(app.buttons["Add Handout"].firstMatch)
        save("planner-handout")
        back()
        back()
        save("planner-campaigns")
        tap(app.buttons["More"])
        save("planner-more-menu")
        for (item, name) in [("Creature Art…", "creature-art"), ("Sync with Nearby Device…", "nearby-sync"),
                             ("About", "about")] {
            if !app.buttons[item].exists { tap(app.buttons["More"]) }
            tap(app.buttons[item])
            save("planner-\(name)")
            closeSheet()
        }
        tap(app.buttons["Add Campaign"])
        save("planner-new-campaign")
    }

    // MARK: Steps

    private func launch(_ demo: String) {
        app.launchArguments = ["--demo", demo, "--fake-voice", "17,nineteen"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        sleep(2)
    }

    private func save(_ name: String) {
        sleep(1)
        let file = folder.appendingPathComponent("\(name).png")
        XCTAssertNoThrow(try XCUIScreen.main.screenshot().pngRepresentation.write(to: file))
    }

    private func tap(_ element: XCUIElement) {
        guard element.waitForExistence(timeout: 4) else {
            XCTFail("Nothing to tap: \(element)")
            return
        }
        element.tap()
    }

    private func tapStrip(_ name: String) {
        tap(strip(name))
    }

    private func strip(_ name: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ AND NOT (label CONTAINS 'turn')", name)).firstMatch
    }

    private func openMenu(ofStrip name: String) {
        let strip = strip(name)
        if strip.waitForExistence(timeout: 4) { strip.press(forDuration: 1.2) }
    }

    private func scroll(to element: XCUIElement) {
        for _ in 0..<10 where !(element.exists && element.isHittable) {
            app.swipeUp()
        }
    }

    private func back() {
        let button = app.navigationBars.buttons.element(boundBy: 0)
        if button.waitForExistence(timeout: 3) { button.tap() }
    }

    private func dismissMenu() {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6)).tap()
    }

    /// Closes a sheet by its Done, Cancel or Close button, else by swiping it down.
    private func closeSheet() {
        for title in ["Done", "Cancel", "Close"] where app.buttons[title].exists {
            app.buttons[title].firstMatch.tap()
            return
        }
        app.swipeDown(velocity: .fast)
        if app.buttons["Set"].exists || app.buttons["Damage"].exists {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        }
    }
}
