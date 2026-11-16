import Foundation
import Testing
@testable import TurnkeeperKit

@Suite("Renaming a strip")
struct RenameTests {
    @Test("The new name is trimmed and the strip keeps its place and turn")
    func renamed() {
        var (state, ids) = fight()
        state.rename(ids[2], to: "  Grumbling Ogre \n")
        #expect(state[ids[2]]?.name == "Grumbling Ogre")
        #expect(state.order == ids)
        #expect(state.currentID == ids[0])
    }

    @Test("A blank name changes nothing", arguments: ["", "   ", "\n\t"])
    func blankIgnored(name: String) {
        var (state, ids) = fight()
        let before = state
        state.rename(ids[0], to: name)
        #expect(state == before)
    }

    @Test("An unknown strip changes nothing")
    func unknownIgnored() {
        var (state, _) = fight()
        let before = state
        state.rename(UUID(), to: "Nobody")
        #expect(state == before)
    }

    @Test("The player screen shows the new name")
    func playerScreen() {
        var (state, ids) = fight()
        state.rename(ids[0], to: "Goblin Archer")
        let names = state.playerScreen { _ in 0 }.lines.map(\.name)
        #expect(names == ["Goblin Archer", "Valeros", "Ogre"])
    }
}
