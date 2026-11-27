import XCTest

/// Sharing the player screen with other devices, checked on one: the app follows the table it shares itself,
/// over the network as another device would.
final class SharingUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    /// A follower sees the order and how hurt the enemies look, a tap on a strip shows that creature's art large,
    /// and leaving goes back to the app underneath.
    func testFollowingShowsTheFightAndATappedCreaturesArt() {
        app.launchArguments = ["--demo", "board", "--demo-art", "--share-table", "4321",
                               "--follow-table", "self", "4321"]
        app.launch()
        let warrior = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Goblin Warrior 2'")).firstMatch
        XCTAssertTrue(warrior.waitForExistence(timeout: 15), "The follower never showed the fight")
        XCTAssertTrue(warrior.label.contains("Bloodied"), "The strip reads \(warrior.label)")
        XCTAssertFalse(warrior.label.contains("2/6"), "The strip gives away hit points: \(warrior.label)")

        let chanter = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Goblin War Chanter'")).firstMatch
        chanter.tap()
        let enlarged = app.buttons["Goblin War Chanter, enlarged"]
        XCTAssertTrue(enlarged.waitForExistence(timeout: 5))
        enlarged.tap()
        XCTAssertTrue(waitUntil { !enlarged.exists })

        // Quick PCs have no card back to show.
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Kyra'")).firstMatch.tap()
        XCTAssertFalse(app.buttons["Kyra, enlarged"].waitForExistence(timeout: 2))

        app.buttons["Leave Table"].tap()
        let next = app.buttons["Next"]
        XCTAssertTrue(waitUntil { next.isHittable }, "Leaving didn't go back to the board")
    }

    /// From the More menu: a wrong code is refused, the right one joins, and with no fight open the follower
    /// is told the GM hasn't started one.
    func testJoiningATableWithItsCode() {
        app.launchArguments = ["--demo", "planner", "--share-table", "4321"]
        app.launch()
        follow(code: "0000")
        let refused = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'code doesn’t match' "
                                                           + "OR label CONTAINS %@", "code doesn't match")).firstMatch
        XCTAssertTrue(refused.waitForExistence(timeout: 10),
                      "Shown instead: \(app.staticTexts.allElementsBoundByIndex.map { $0.label })")
        app.buttons["Leave Table"].tap()

        follow(code: "4321")
        XCTAssertTrue(app.staticTexts["Waiting for the GM to start a fight"].waitForExistence(timeout: 10))
        app.buttons["Leave Table"].tap()
        XCTAssertTrue(waitUntil { self.app.buttons["More"].isHittable })
    }

    /// Opens Follow a Table from the campaign list's More menu and joins the only table nearby, this device's.
    private func follow(code: String) {
        let more = app.buttons["More"]
        // The campaign list is behind the encounter on an iPhone, and may be hidden on an upright iPad.
        for _ in 0..<3 where !(more.exists && more.isHittable) {
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        more.tap()
        app.buttons["Follow a Table…"].tap()
        let field = app.textFields["Code"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        let looking = app.staticTexts["Looking for a GM sharing the player screen…"]
        XCTAssertTrue(waitUntil(timeout: 10) { !looking.exists }, "No table was found to follow")
        field.tap()
        // The code of the table joined last is filled in; start from an empty field.
        let filled = (field.value as? String) ?? ""
        if filled != "Code" { field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: filled.count)) }
        field.typeText(code)
        // Typing the fourth digit follows; no tap on Follow, which the on-screen keyboard would take first.
        XCTAssertTrue(waitUntil { !field.exists }, "Typing the code didn't follow")
    }

    private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return condition()
    }
}
