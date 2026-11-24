import XCTest

/// Setup no longer rolls for creatures, Begin Combat warns about anyone without an initiative, and the voice
/// initiative screen enters totals row by row.
final class InitiativeUITests: XCTestCase {
    func testBeginCombatWarnsAboutMissingInitiative() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "setup"]
        app.launch()
        let begin = app.buttons["Begin Combat"]
        XCTAssertTrue(begin.waitForExistence(timeout: 10))
        begin.tap()
        let warning = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "no initiative yet"))
        XCTAssertTrue(warning.firstMatch.waitForExistence(timeout: 5))
        app.buttons["Go Back"].tap()
        XCTAssertTrue(begin.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Next"].exists)
    }

    /// With scripted speech: a number goes to the selected row and the selection moves on, a name selects its
    /// row, "nat 20" adds a linked PC's modifier, and only Done closes the screen.
    func testVoiceInitiativeScreen() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "setup", "--fake-voice", "nat 20,Merisiel,seventeen,twenty"]
        app.launch()
        let open = app.buttons["Voice Initiative"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        open.tap()
        let start = app.buttons["Start Listening"]
        XCTAssertTrue(start.waitForExistence(timeout: 5), "the help explains the screen before it listens")
        start.tap()
        let status = app.staticTexts["voiceStatus"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertTrue(waitUntil(timeout: 10) { status.label == "Heard 20 for Ezren" }, "status is \(status.label)")

        // Valeros has a sheet, so his natural 20 has his best modifier added.
        let valeros = row("Valeros", in: app)
        XCTAssertTrue(waitUntil { self.initiative(of: valeros).map { $0 > 20 } ?? false }, valeros.label)
        XCTAssertEqual(initiative(of: row("Merisiel", in: app)), 17)
        XCTAssertEqual(initiative(of: row("Ezren", in: app)), 20)
        XCTAssertNil(initiative(of: row("Kyra", in: app)))
        XCTAssertTrue(row("Kyra", in: app).isSelected, "the selection moves on to the row without one")

        row("Valeros", in: app).tap()
        XCTAssertTrue(waitUntil { self.row("Valeros", in: app).isSelected })
        app.buttons["voiceDone"].tap()
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        XCTAssertFalse(status.exists)
    }

    /// The help opens before listening each time until Don't Show Again; after that only the help button opens it,
    /// and closing it from there leaves the screen listening.
    func testVoiceInitiativeHelp() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "setup", "--fake-voice", "mumble"]
        app.launch()
        let open = app.buttons["Voice Initiative"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        open.tap()
        XCTAssertTrue(app.buttons["Start Listening"].waitForExistence(timeout: 5))
        app.buttons["Start Listening"].tap()
        app.buttons["voiceDone"].tap()

        open.tap()
        XCTAssertTrue(app.buttons["Don't Show Again"].waitForExistence(timeout: 5), "it shows again")
        app.buttons["Don't Show Again"].tap()
        app.buttons["voiceDone"].tap()

        open.tap()
        XCTAssertTrue(app.buttons["voiceDone"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Start Listening"].exists, "Don't Show Again stops it opening by itself")
        app.buttons["How It Works"].tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Start Listening"].exists)
        app.buttons["Done"].firstMatch.tap()
        // The prompt shows only while listening.
        let prompt = app.staticTexts["voiceTranscript"]
        XCTAssertTrue(waitUntil { prompt.label == "Say a name or a number…" }, "not listening: \(prompt.label)")
    }

    private func row(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["voiceRow.\(name)"].firstMatch
    }

    /// The number a row starts with, such as 17 from "17, Merisiel"; nil for "–".
    private func initiative(of row: XCUIElement) -> Double? {
        guard row.waitForExistence(timeout: 3) else { return nil }
        return Double(row.label.prefix { $0.isNumber || $0 == "." })
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
