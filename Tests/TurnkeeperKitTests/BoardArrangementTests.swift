import Testing
@testable import TurnkeeperKit

@Suite("Board arrangement")
struct BoardArrangementTests {
    @Test("The card sits beside the ladder only with room for both", arguments: [
        // An iPad in landscape and in portrait, and a Mac window.
        (1194.0, 760.0, BoardArrangement.sideBySide), (834.0, 1100.0, .sideBySide), (1280.0, 800.0, .sideBySide),
        // An iPhone upright, an iPhone on its side, an iPad in a narrow split, and exactly the minimum width.
        (402.0, 760.0, .ladderOnly), (874.0, 340.0, .ladderOnly), (507.0, 1100.0, .ladderOnly),
        (760.0, 900.0, .ladderOnly),
        // Exactly the minimum height is enough.
        (800.0, 480.0, .sideBySide)
    ])
    func arrangement(width: Double, height: Double, expected: BoardArrangement) {
        #expect(BoardArrangement(width: width, height: height) == expected)
    }

    @Test("The turn buttons get their own bar only on a board tall enough to spare it")
    func turnBar() {
        #expect(BoardArrangement.hasTurnBar(height: 760))
        #expect(BoardArrangement.hasTurnBar(height: 480))
        #expect(!BoardArrangement.hasTurnBar(height: 340))
    }

    @Test("The ladder takes just under half beside the card, and everything alone")
    func ladderWidth() {
        #expect(BoardArrangement.sideBySide.ladderWidth(in: 1000) == 480)
        #expect(BoardArrangement.ladderOnly.ladderWidth(in: 402) == 402)
    }
}
