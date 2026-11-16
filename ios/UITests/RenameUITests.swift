import XCTest

/// Runs the demo fight (`--demo board`) and renames the current strip from its menu (R4.8c).
final class RenameUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--demo", "board"]
        app.launch()
    }

    func testRenamingAStripFromItsMenu() {
        XCTAssertTrue(app.buttons["Next"].waitForExistence(timeout: 10))
        let current = app.descendants(matching: .any).matching(NSPredicate(format: "selected == true")).firstMatch
        XCTAssertTrue(current.waitForExistence(timeout: 5))
        current.press(forDuration: 1.2)
        let rename = app.buttons["Rename…"]
        XCTAssertTrue(rename.waitForExistence(timeout: 5), "The strip menu has no Rename…")
        rename.tap()

        let field = app.textFields["Name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), app.debugDescription)
        field.tap()
        field.clearAndType("Sneaky Archer")
        app.buttons["Rename"].tap()

        let renamed = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Sneaky Archer'"))
        XCTAssertTrue(renamed.firstMatch.waitForExistence(timeout: 5), "The strip kept its old name")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Renamed"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

private extension XCUIElement {
    /// Replaces the field's text: selects it all with as many deletes as it has characters, then types.
    func clearAndType(_ text: String) {
        let current = value as? String ?? ""
        typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + text)
    }
}
