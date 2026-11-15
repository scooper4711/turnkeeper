import XCTest

/// What differs between running the tests on an iPad and on an iPhone, where the board shows the ladder alone
/// and the planner one column at a time.
enum TestDevice {
    /// The model the tests run on, such as "iPhone18,1": the simulated one in a simulator.
    static var isPhone: Bool {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated.hasPrefix("iPhone")
        }
        var system = utsname()
        uname(&system)
        let machine = withUnsafeBytes(of: &system.machine) { String(bytes: $0.prefix { $0 != 0 }, encoding: .utf8) }
        return machine?.hasPrefix("iPhone") ?? false
    }
}

extension XCUIApplication {
    /// The acting combatant's battle card: beside the ladder on an iPad, opened from the Card button on an iPhone.
    func showBoardCard() {
        guard TestDevice.isPhone else { return }
        let card = buttons["Card"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()
    }

    /// Back to the ladder: on an iPhone, closes the card's sheet.
    func closeBoardCard() {
        guard TestDevice.isPhone else { return }
        buttons["Done"].firstMatch.tap()
    }

    /// From the planner's detail page to the campaign's list: on an iPhone they are one behind the other.
    func showCampaignList() {
        guard TestDevice.isPhone else { return }
        let back = navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(back.waitForExistence(timeout: 10))
        back.tap()
    }
}
