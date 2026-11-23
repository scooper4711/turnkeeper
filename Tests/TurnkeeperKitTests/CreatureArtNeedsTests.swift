import Bestiary
import Foundation
import Testing
@testable import TurnkeeperKit

@Suite("Which missing PDFs creatures need")
struct CreatureArtNeedsTests {
    private let pawnBox = "Pathfinder Pawn Box"

    private func creature(_ name: String, art: ArtReference = .none) -> BestiaryIndexEntry {
        var creature = Creature(key: name.lowercased(), name: name, game: .pathfinder)
        creature.art = art
        return BestiaryIndexEntry(creature: creature)
    }

    private func art(_ name: String, isAvailable: Bool = false) -> LibraryArt {
        LibraryArt(id: UUID(), name: name, game: .pathfinder, isRemastered: false, isToken: false,
                   isAvailable: isAvailable, sourceTitles: [pawnBox])
    }

    private func titles(
        of creatures: [BestiaryIndexEntry], art: [LibraryArt], customArt: Set<String> = []
    ) -> Set<String> {
        CreatureArtNeeds.sourceTitles(of: creatures, matcher: LibraryArtMatcher(art: art),
                                      customArtSubjects: customArt)
    }

    @Test("A creature whose only art can't be shown needs its PDF")
    func creatureNeedsPDF() {
        #expect(titles(of: [creature("Goblin")], art: [art("Goblin")]) == [pawnBox])
    }

    @Test("A pawn no creature is named for needs nothing")
    func pawnWithoutCreature() {
        #expect(titles(of: [creature("Goblin")], art: [art("Zarfzarf")]).isEmpty)
    }

    @Test("A creature with other art that can be shown needs nothing")
    func otherArtAvailable() {
        let art = [art("Goblin"), art("Goblin", isAvailable: true)]
        #expect(titles(of: [creature("Goblin")], art: art).isEmpty)
    }

    @Test("A creature with its own or pasted art needs nothing")
    func ownArt() {
        let bundled = ArtReference(portrait: "goblin.png", token: "goblin.png", cardBack: "")
        #expect(titles(of: [creature("Goblin", art: bundled)], art: [art("Goblin")]).isEmpty)
        #expect(titles(of: [creature("Goblin")], art: [art("Goblin")], customArt: ["goblin"]).isEmpty)
    }
}
