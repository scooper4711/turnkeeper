import Bestiary
import Foundation
import SharedLibraries
import Testing
@testable import TurnkeeperKit

@Suite("Shared creature library")
struct SharedCreatureStoreTests {
    private let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("SharedCreatureStoreTests-\(UUID().uuidString)", isDirectory: true)

    private func makeStore(_ name: String = "Shared") throws -> SharedCreatureStore {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let shared = try SharedLibrary(folder: folder.appendingPathComponent(name), app: .turnkeeper)
        return try SharedCreatureStore(shared: shared, positionFile: folder.appendingPathComponent("position.json"))
    }

    private func otherApp(_ store: SharedCreatureStore) throws -> SharedLibrary {
        try SharedLibrary(folder: store.shared.folder, app: .pawnShop)
    }

    private func pawnRow(name: String = "Gwibble", size: CreatureSize? = .tiny) -> CustomCreatureRecord {
        CustomCreatureRecord(id: UUID(), name: name, campaignID: nil, sharedVersion: nil, record: Data(), size: size)
    }

    private func encounter(with key: String) -> Encounter {
        var encounter = Encounter(scenarioID: UUID(), name: "A")
        var variant = encounter.variant("Base")
        variant.slots.append(EncounterSlot(creatureKey: key))
        encounter.setVariant(variant)
        return encounter
    }

    @Test("Moving in brings creatures and pasted art, with the image, once")
    func movesIn() throws {
        let store = try makeStore()
        let pasted = folder.appendingPathComponent("Art", isDirectory: true)
        try FileManager.default.createDirectory(at: pasted, withIntermediateDirectories: true)
        try Data("image".utf8).write(to: pasted.appendingPathComponent("a.jpg"))
        var library = Library()
        let custom = CustomCreature(campaignID: UUID(), game: .starfinder, name: "Drone")
        library.save(custom)
        library.save(CustomArt(subject: custom.key, fileName: "a.jpg", byteCount: 5))

        try store.moveIn(library, artFolder: folder.appendingPathComponent("None"), pastedArtFolder: pasted)
        try store.moveIn(Library(), artFolder: folder.appendingPathComponent("None"), pastedArtFolder: pasted)

        var read = Library()
        try store.pull(into: &read)
        #expect(read.customCreature(key: custom.key)?.creature.game == .starfinder)
        #expect(read.customArt(for: custom.key)?.fileName == "a.jpg")
        #expect(store.artStore.contains("a.jpg"))
        #expect(!FileManager.default.fileExists(atPath: pasted.appendingPathComponent("a.jpg").path))
    }

    @Test("A pawn without a stat block lists by name and size, then takes a campaign and game with one")
    func nameOnly() throws {
        let store = try makeStore()
        let row = pawnRow()
        try otherApp(store).save(row)
        var library = Library()
        try store.pull(into: &library)
        let pawn = try #require(library.customCreatures.first)
        #expect(!pawn.hasStatBlock && pawn.creature.name == "Gwibble" && pawn.creature.traits.size == "Tiny")

        try store.push(library)
        #expect(try store.shared.customCreatures().first?.record.isEmpty == true, "reading it writes no stat block")

        let campaignID = UUID()
        var statBlock = pawn.creature
        statBlock.level = 3
        library.save(pawn.givingStatBlock(statBlock, campaignID: campaignID, game: .starfinder))
        try store.push(library)
        let saved = try #require(try store.shared.customCreatures().first)
        #expect(saved.hasStatBlock && saved.game == .starfinder && saved.campaignID == campaignID)
    }

    @Test("The row's name and size win over the record's, and are written back")
    func rowWins() throws {
        let store = try makeStore()
        var library = Library()
        var custom = CustomCreature(campaignID: UUID(), game: .pathfinder, name: "Old")
        custom.creature.traits.size = "Medium"
        library.save(custom)
        try store.push(library)
        let other = try otherApp(store)
        try other.renameCustomCreature(id: custom.id, to: "New")
        try other.setCustomCreatureSize(.tiny, id: custom.id)

        try store.pull(into: &library)
        let read = try #require(library.customCreature(key: custom.key))
        #expect(read.creature.name == "New" && read.creature.traits.size == "Tiny")
        #expect(read.modifiedAt > custom.modifiedAt, "sharing the library has to carry the rename")
        try store.push(library)
        let row = try #require(try store.shared.customCreatures().first)
        let record = try JSONDecoder().decode(CustomCreature.self, from: row.record)
        #expect(record.creature.name == "New" && record.creature.traits.size == "Tiny")
    }

    @Test("A deletion from another app takes the creature out of every encounter")
    func deletionReachesEncounters() throws {
        let store = try makeStore()
        let row = pawnRow()
        try otherApp(store).save(row)
        var library = Library()
        try store.pull(into: &library)
        let key = CustomCreature.keyPrefix + row.id.uuidString
        library.save(encounter(with: key))

        try otherApp(store).removeCustomCreature(id: row.id)
        try store.pull(into: &library)
        #expect(library.customCreature(key: key) == nil)
        #expect(library.encounters[0].variants.allSatisfy { $0.slots.isEmpty })
    }

    @Test("A creature merely absent from this library stays in its encounters")
    func absentIsNotDeleted() throws {
        let store = try makeStore("Empty")
        var library = Library()
        let key = CustomCreature.keyPrefix + UUID().uuidString
        library.save(encounter(with: key))
        try store.pull(into: &library)
        #expect(library.encounters[0].variants.contains { $0.slots.contains { $0.creatureKey == key } })
    }

    @Test("A deletion made while the app was closed is applied at the next launch")
    func deletionWhileClosed() throws {
        let store = try makeStore()
        let row = pawnRow()
        try otherApp(store).save(row)
        var library = Library()
        try store.pull(into: &library)
        let key = CustomCreature.keyPrefix + row.id.uuidString
        library.save(encounter(with: key))
        try store.savePosition()

        try otherApp(store).removeCustomCreature(id: row.id)
        var relaunched = library.keepingOnlyLocalRecords()
        try makeStore().pull(into: &relaunched)
        #expect(relaunched.encounters[0].variants.allSatisfy { $0.slots.isEmpty })
    }

    @Test("A stat block this version can't read is left alone")
    func unreadableRecordSurvives() throws {
        let store = try makeStore()
        let unreadable = Data("{\"from\":\"the future\"}".utf8)
        let row = CustomCreatureRecord(id: UUID(), name: "Future", campaignID: nil, sharedVersion: nil,
                                       record: unreadable)
        try otherApp(store).save(row)
        var library = Library()
        try store.pull(into: &library)
        try store.push(library)
        #expect(try store.shared.customCreatures().first?.record == unreadable)
    }

    @Test("Deleting in Turnkeeper removes the creature and its art from the shared library")
    func deleteRemovesArt() throws {
        let store = try makeStore()
        var library = Library()
        let custom = CustomCreature(campaignID: UUID(), game: .pathfinder, name: "Gone")
        library.save(custom)
        let stored = try store.artStore.store(Self.pngImage)
        library.save(CustomArt(subject: custom.key, fileName: stored.fileName, byteCount: stored.byteCount))
        try store.push(library)
        #expect(try store.shared.creatureArt()[custom.key] != nil)

        library.deleteCustomCreature(custom.id)
        try store.push(library)
        try store.pull(into: &library)
        #expect(try store.shared.customCreatures().isEmpty && store.shared.customArt().isEmpty)
        #expect(!store.artStore.contains(stored.fileName))
        #expect(library.customArt(for: custom.key) == nil)
    }

    @Test("library.json keeps deletions only")
    func localRecords() {
        var library = Library()
        let kept = CustomCreature(campaignID: UUID(), game: .pathfinder, name: "Kept")
        let deleted = CustomCreature(campaignID: UUID(), game: .pathfinder, name: "Deleted")
        library.save(kept)
        library.save(deleted)
        library.deleteCustomCreature(deleted.id)
        #expect(library.keepingOnlyLocalRecords().customCreatures.map(\.id) == [deleted.id])
    }

    @Test("Custom creatures list the scenario's first, then the campaign's, then the rest")
    func listingOrder() {
        var library = Library()
        let campaignID = UUID(), scenarioID = UUID()
        var inScenario = CustomCreature(campaignID: campaignID, game: .pathfinder, name: "Zed")
        inScenario.scenarioID = scenarioID
        library.save(CustomCreature(campaignID: UUID(), game: .pathfinder, name: "Abe"))
        library.save(CustomCreature(campaignID: campaignID, game: .pathfinder, name: "Moe"))
        library.save(inScenario)
        let names = library.customCreaturesListed(campaignID: campaignID, scenarioID: scenarioID).map(\.creature.name)
        #expect(names == ["Zed", "Moe", "Abe"])
    }

    @Test("A campaign's package carries a creature from elsewhere that its encounters use")
    func packageCarriesUsedCreatures() {
        var library = Library()
        let campaign = Campaign(name: "C", game: .pathfinder)
        let scenario = Scenario(campaignID: campaign.id, name: "S")
        let custom = CustomCreature(campaignID: UUID(), game: .pathfinder, name: "Guest")
        var fight = encounter(with: custom.key)
        fight.scenarioID = scenario.id
        library.save(campaign)
        library.save(scenario)
        library.save(custom)
        library.save(fight)
        let package = LibraryPackage(picking: .everything(in: campaign.id, of: library), from: library,
                                     bestiaryRevision: "")
        #expect(package.library.customCreatures.map(\.id) == [custom.id])
    }

    /// A 1×1 PNG.
    private static let pngImage = Data(base64Encoded:
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M/AAAMBAQAY3Y2wAAAAAElFTkSuQmCC") ?? Data()
}
