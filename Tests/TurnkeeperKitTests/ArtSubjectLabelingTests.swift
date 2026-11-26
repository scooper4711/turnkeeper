import Foundation
import SharedLibraries
import Testing
@testable import TurnkeeperKit

@Suite("The creature's name saved with pasted art")
struct ArtSubjectLabelingTests {
    private let rimesnap = "pf2e.pfs-season-6-bestiary.GMKVSvtmRxBacSKH"

    /// What the app knows of the creatures: the bestiary's, and nothing of one that left it.
    private func label(_ key: String) -> ArtSubjectLabel? {
        switch key {
        case rimesnap: ArtSubjectLabel(name: "Rimesnap", size: .tiny)
        case "pf2e.pack.swarm": ArtSubjectLabel(name: "Zombie Crow Swarm", size: nil)
        default: nil
        }
    }

    private func art(for subject: String) -> CustomArt {
        CustomArt(subject: subject, fileName: "\(UUID().uuidString).png", byteCount: 12)
    }

    private func library(_ art: [CustomArt]) -> Library {
        var library = Library()
        library.customArt = art
        return library
    }

    @Test("A bestiary creature's art takes the creature's name and size")
    func labelsBestiaryArt() {
        var library = library([art(for: rimesnap), art(for: "pf2e.pack.swarm")])
        let pasted = library.customArt.map(\.modifiedAt)
        library.labelArtSubjects(label)
        #expect(library.customArt.map(\.subjectLabel) == [ArtSubjectLabel(name: "Rimesnap", size: .tiny),
                                                          ArtSubjectLabel(name: "Zombie Crow Swarm", size: nil)])
        #expect(zip(library.customArt.map(\.modifiedAt), pasted).allSatisfy { $0 > $1 })
    }

    @Test("Labeling again changes nothing")
    func labelingTwiceIsOnce() {
        var library = library([art(for: rimesnap)])
        library.labelArtSubjects(label)
        let labeled = library
        library.labelArtSubjects(label)
        #expect(library == labeled)
    }

    @Test("A name that changed is saved again")
    func relabelsWhenTheNameDiffers() {
        var old = art(for: rimesnap)
        old.subjectName = "Rime Snap"
        old.subjectSize = .small
        var library = library([old])
        library.labelArtSubjects(label)
        #expect(library.customArt.first?.subjectLabel == ArtSubjectLabel(name: "Rimesnap", size: .tiny))
        #expect(library.customArt.first.map { $0.modifiedAt > old.modifiedAt } == true)
    }

    @Test("A custom creature's, a character's, deleted and unknown creatures' art is left alone")
    func leavesOtherArtAlone() {
        var deleted = art(for: rimesnap)
        deleted.deletedAt = Date()
        let untouched = [art(for: CustomCreature.keyPrefix + UUID().uuidString),
                         art(for: PlayerCharacter.keyPrefix + UUID().uuidString), deleted, art(for: "pf2e.pack.gone")]
        var library = library(untouched)
        library.labelArtSubjects { _ in ArtSubjectLabel(name: "Anything", size: .medium) }
        #expect(library.customArt.prefix(3) == untouched.prefix(3))
        library = self.library(untouched)
        library.labelArtSubjects(label)
        #expect(library.customArt == untouched)
    }

    @Test("The shared library's record carries the name where Tabletop Kit reads it")
    func theSharedRowCarriesTheLabel() throws {
        var library = library([art(for: rimesnap)])
        library.labelArtSubjects(label)
        let row = try SharedCreatureStore.row(try #require(library.customArt.first))
        #expect(row.subjectLabel == ArtSubjectLabel(name: "Rimesnap", size: .tiny))
        #expect(try SharedCreatureStore.row(art(for: rimesnap)).subjectLabel == nil)
    }

    @Test("Art saved before names were kept reads without one, and keeps its bytes")
    func readsArtSavedBefore() throws {
        let saved = #"{"byteCount":12,"fileName":"a.png","id":"550460B8-78E4-4DD2-B404-796987069B7F","#
            + #""modifiedAt":817403167.89,"subject":"pf2e.pack.swarm"}"#
        let art = try JSONDecoder().decode(CustomArt.self, from: Data(saved.utf8))
        #expect(art.subjectLabel == nil && art.subjectName == nil && art.subjectSize == nil)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        #expect(String(bytes: try encoder.encode(art), encoding: .utf8) == saved)
    }
}
