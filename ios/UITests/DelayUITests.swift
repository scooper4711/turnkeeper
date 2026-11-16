import XCTest

/// Runs the demo fight (`--demo board`) and checks the ladder's swipes: left to right delays a strip, which
/// is asked about before the turn passes it; right to left kills an enemy where it stands, and knocks a PC or
/// an ally out, moving it to just before the current strip.
final class DelayUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--demo", "board"]
        app.launch()
    }

    func testSwipingToDelayPassesTheTurnAndAsksBeforePassingIt() {
        XCTAssertTrue(app.buttons["Next"].waitForExistence(timeout: 10))
        let current = currentStrip
        XCTAssertTrue(current.waitForExistence(timeout: 5))
        swipe(current, by: 220)
        let delay = app.alerts.buttons["Delay"]
        XCTAssertTrue(delay.waitForExistence(timeout: 5), "Swiping right asked nothing")
        delay.tap()
        dismissReminders()
        let delaying = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Delaying'"))
        XCTAssertTrue(delaying.firstMatch.waitForExistence(timeout: 5), "No strip shows it is delaying")
        attachScreenshot("Delaying")
        app.buttons["Next"].tap()
        let actNow = app.buttons["Act Now"]
        XCTAssertTrue(actNow.waitForExistence(timeout: 5), "Next didn't ask about the delaying strip")
        attachScreenshot("Asked")
        actNow.tap()
        dismissReminders()
        XCTAssertTrue(waitUntil { delaying.firstMatch.exists == false }, "The strip is still delaying after acting")
    }

    func testSwipingLeftKillsAnEnemyWhereItStands() {
        XCTAssertTrue(app.buttons["Next"].waitForExistence(timeout: 10))
        let name = firstStrip(among: Self.enemies)
        let orderBefore = ladderOrder()
        swipe(strip(named: name), by: -220)
        XCTAssertTrue(waitUntil { self.strip(named: name).label.contains("Dead") }, "\(name) didn't die")
        XCTAssertFalse(conditions(of: name).contains("Dying"), "\(name) is dying, not dead")
        XCTAssertEqual(ladderOrder(), orderBefore, "\(name) moved in the order")
        attachScreenshot("Dead")
    }

    func testSwipingLeftKnocksAPCOutBeforeTheCurrentStrip() {
        XCTAssertTrue(app.buttons["Next"].waitForExistence(timeout: 10))
        let name = firstStrip(among: Self.party)
        swipe(strip(named: name), by: -220)
        expectKnockedOutBeforeTheCurrentStrip(name)
        attachScreenshot("PC knocked out")
    }

    func testSwipingLeftKnocksAnAllyOutBeforeTheCurrentStrip() {
        XCTAssertTrue(app.buttons["Next"].waitForExistence(timeout: 10))
        let name = firstStrip(among: Self.enemies)
        // Pressed by its name, clear of the condition chips, which are a button of their own.
        strip(named: name).coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.25)).press(forDuration: 1.2)
        // The Side picker shows its choices in the menu itself, or behind Side.
        let side = app.buttons["Side"].firstMatch
        if side.waitForExistence(timeout: 2) { side.tap() }
        let ally = app.buttons["Ally"].firstMatch
        XCTAssertTrue(ally.waitForExistence(timeout: 5), "The strip menu has no Ally: \(app.debugDescription)")
        ally.tap()
        swipe(strip(named: name), by: -220)
        expectKnockedOutBeforeTheCurrentStrip(name)
        attachScreenshot("Ally knocked out")
    }

    /// The strip whose turn it is: the one marked selected.
    private var currentStrip: XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "selected == true")).firstMatch
    }

    private static let enemies = ["Goblin Warrior 1", "Goblin Warrior 2", "Goblin Warrior 3"]
    private static let party = ["Ezren", "Kyra", "Merisiel", "Valeros"]
    /// The rest of the demo fight, which may hold the current turn.
    private static let others = ["Goblin War Chanter", "Drowning Pit"]

    /// The strip of `name`: a button whose parts read as one label, "22, Kyra", after any status such as Dead.
    /// The card beside the ladder names the current creature too, so only strips' labels are searched.
    private func strip(named name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", ", \(name)")).firstMatch
    }

    /// The strip's conditions, which it reads after its name: "Dying 1, Unconscious, Prone".
    private func conditions(of name: String) -> String {
        strip(named: name).value as? String ?? ""
    }

    /// The first of `names` on the ladder that isn't taking its turn, so knocking it out moves it.
    private func firstStrip(among names: [String]) -> String {
        let current = currentStrip.label
        let name = names.first { strip(named: $0).exists && !current.contains($0) }
        XCTAssertNotNil(name, "None of \(names) is on the ladder: \(app.debugDescription)")
        return name ?? ""
    }

    /// The combatants' names, top to bottom.
    private func ladderOrder() -> [String] {
        (Self.enemies + Self.party + Self.others)
            .filter { strip(named: $0).exists }
            .sorted { strip(named: $0).frame.minY < strip(named: $1).frame.minY }
    }

    private func expectKnockedOutBeforeTheCurrentStrip(_ name: String, line: UInt = #line) {
        XCTAssertTrue(waitUntil { self.conditions(of: name).contains("Dying") }, "\(name) isn't dying",
                      line: line)
        XCTAssertFalse(strip(named: name).label.contains("Dead"), "\(name) died", line: line)
        // The strips slide into their new order, so it is read again until it settles.
        XCTAssertTrue(waitUntil { self.stripAfter(name) == self.currentName() },
                      "\(name) isn't just before the current strip: \(ladderOrder())", line: line)
    }

    /// The strip below `name`'s on the ladder; nil when it is last.
    private func stripAfter(_ name: String) -> String? {
        let order = ladderOrder()
        guard let index = order.firstIndex(of: name), index + 1 < order.count else { return nil }
        return order[index + 1]
    }

    private func currentName() -> String? {
        let label = currentStrip.label
        return (Self.enemies + Self.party + Self.others).first { label.contains($0) }
    }

    /// A quick sideways drag across a strip, like a finger's swipe.
    private func swipe(_ strip: XCUIElement, by distance: CGFloat) {
        let start = strip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: distance, dy: 0)),
                    withVelocity: .fast, thenHoldForDuration: 0)
    }

    private func dismissReminders() {
        while app.buttons["Got It"].waitForExistence(timeout: 2) { app.buttons["Got It"].tap() }
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
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
