import XCTest

/// Share Pawn Sheet (R3.9.5, R3.9.6), against the demo library: a Society scenario with two difficulties.
final class PawnSheetUITests: XCTestCase {
    private var app: XCUIApplication!
    private let encounterName = "A: Ambush on the Docks"

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    /// An encounter's context menu offers the sheet for all difficulties or one, and choosing one opens the
    /// system's share sheet.
    func testAnEncounterSharesItsPawnSheet() {
        openTheShareSheet()
        XCTAssertTrue(shareSheet.waitForExistence(timeout: 15), "the share sheet didn't open")
    }

    /// The whole way into Pawn Shop. Only where Pawn Shop is installed beside Turnkeeper, which CI's simulator
    /// doesn't have: run with `TEST_RUNNER_PAWN_SHOP_HANDOFF=1` after installing Pawn Shop's simulator build.
    func testPawnShopOpensTheSharedSheet() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["PAWN_SHOP_HANDOFF"] == "1",
                          "needs Pawn Shop on the same simulator")
        openTheShareSheet()
        XCTAssertTrue(shareSheet.waitForExistence(timeout: 15), "the share sheet didn't open")
        let target = shareSheet.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS[c] 'Pawn Shop'")).firstMatch
        XCTAssertTrue(target.waitForExistence(timeout: 10), "the share sheet doesn't offer Pawn Shop")
        target.tap()
        XCTAssertTrue(pawnShop.wait(for: .runningForeground, timeout: 20), "Pawn Shop didn't come forward")
        let title = pawnShop.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS 'Ambush on the Docks'")).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 20), "Pawn Shop shows no sheet named after the encounter")
    }

    private var shareSheet: XCUIElement { app.otherElements["ActivityListView"] }

    /// The encounter's row in the campaign list. Its name is also the page's title, to the right of the list on
    /// an iPad: the row is the leftmost.
    private var listRow: XCUIElement? {
        app.staticTexts.matching(identifier: encounterName).allElementsBoundByIndex
            .min { $0.frame.minX < $1.frame.minX }
    }

    private var pawnShop: XCUIApplication { XCUIApplication(bundleIdentifier: "io.github.scooper4711.PawnShop") }

    private func openTheShareSheet() {
        app.launchArguments = ["--demo", "planner"]
        app.launch()
        XCTAssertTrue(app.navigationBars[encounterName].waitForExistence(timeout: 10))
        app.showCampaignList()
        XCTAssertTrue(app.staticTexts[encounterName].firstMatch.waitForExistence(timeout: 10))
        let share = app.buttons["Share Pawn Sheet"]
        // A press that lands while the list is still settling opens no menu: press again.
        for _ in 0..<3 where !share.exists {
            listRow?.press(forDuration: 1.2)
            _ = share.waitForExistence(timeout: 4)
        }
        XCTAssertTrue(share.exists, "the context menu has no Share Pawn Sheet")
        share.tap()
        let all = app.buttons["All Difficulties"]
        XCTAssertTrue(all.waitForExistence(timeout: 5), "a Society scenario offers All Difficulties")
        XCTAssertTrue(app.buttons["10–12 CP"].exists && app.buttons["16–18 CP"].exists)
        all.tap()
    }
}
