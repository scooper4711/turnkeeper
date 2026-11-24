import CloudKit
import Foundation
import TablesideSync
import Testing
@testable import TurnkeeperKit

@MainActor
@Suite("Syncing campaigns through iCloud")
struct CampaignSyncTests {
    @Test("Every kind of record round-trips, deleted ones included")
    func everyKind() throws {
        let mac = SyncDevice(), ipad = SyncDevice()
        var library = Library()
        let campaign = Campaign(name: "Season 7", game: .pathfinder)
        library.save(campaign)
        library.save(Party(campaignID: campaign.id, name: "Party", level: 3))
        let scenario = Scenario(campaignID: campaign.id, name: "Scenario")
        library.save(scenario)
        let encounter = Encounter(scenarioID: scenario.id, name: "Encounter")
        library.save(encounter)
        let context = SessionContext(campaignID: campaign.id, encounterID: encounter.id, variantLabel: "Base",
                                     name: "Fight")
        library.save(CombatSession(context: context, state: CombatState(combatants: [], events: [])))
        library.save(Handout(scenarioID: scenario.id, name: "Map"))
        library.save(CreatureNote(scenarioID: scenario.id, subject: "goblin", text: "Carries the key"))
        library.deleteHandout(try #require(library.handouts.first).id)
        mac.host.library = library
        ipad.download(mac.upload())
        #expect(ipad.host.library.campaigns.map(\.name) == ["Season 7"])
        #expect(ipad.host.library.parties.count == 1 && ipad.host.library.scenarios.count == 1)
        #expect(ipad.host.library.encounters.count == 1 && ipad.host.library.sessions.count == 1)
        #expect(ipad.host.library.creatureNotes.map(\.text) == ["Carries the key"])
        #expect(ipad.host.library.handouts.first?.isDeleted == true)
        #expect(ipad.pendingCount == 0)
    }

    @Test("A large payload goes up as an asset and comes back whole")
    func largePayload() throws {
        let mac = SyncDevice(), ipad = SyncDevice()
        var encounter = Encounter(scenarioID: UUID(), name: "Long")
        encounter.notes = String(repeating: "x", count: CampaignRecordCoder.inlinePayloadLimit + 1)
        mac.host.library.save(encounter)
        let record = try mac.nextAttempt()
        #expect(record["payload"] == nil && record["payloadAsset"] is CKAsset)
        ipad.download([record])
        #expect(ipad.host.library.encounters.first?.notes.count == encounter.notes.count)
    }

    @Test("A handout's image arrives before its record is merged")
    func handoutImage() throws {
        let mac = SyncDevice(), ipad = SyncDevice()
        let store = try #require(mac.host.handoutImages)
        try store.write(Data([1, 2, 3]), as: "map.jpg")
        var handout = Handout(scenarioID: UUID(), name: "Map")
        handout.fileName = "map.jpg"
        mac.host.library.save(handout)
        ipad.download(mac.upload())
        #expect(ipad.host.handoutImages?.data(for: "map.jpg") == Data([1, 2, 3]))
    }

    @Test("A file name from the server can't leave the image folder")
    func imageNames() {
        #expect(CampaignSync.isPlainFileName("map.jpg"))
        for name in ["", ".", "..", "../library.json", "a/b.jpg", "a\\b.jpg"] {
            #expect(!CampaignSync.isPlainFileName(name))
        }
    }

    @Test("Nothing is sent back after receiving")
    func noEcho() {
        let (mac, ipad) = SyncDevice.pair()
        #expect(ipad.pendingCount == 0 && mac.pendingCount == 0)
    }

    @Test("Custom creatures and art never go through Turnkeeper's zone")
    func sharedRecordsStayOut() {
        let mac = SyncDevice()
        mac.host.library.save(CustomArt(subject: "goblin", fileName: "goblin.jpg", byteCount: 3))
        #expect(mac.pendingCount == 0)
    }

    @Test("Many edits on one device make no conflict copy, past the cap on remembered versions")
    func manyEdits() {
        let (mac, ipad) = SyncDevice.pair()
        for edit in 0..<(Encounter.sharedVersionLimit + 5) {
            mac.editNotes("Edit \(edit)")
            ipad.download(mac.upload())
        }
        #expect(ipad.encounterNames == ["A. Signal Jammer"])
        #expect(ipad.host.library.encounters[0].notes == "Edit \(Encounter.sharedVersionLimit + 4)")
    }

    @Test("A device behind by more than the cap takes the other's version without a copy")
    func farBehind() {
        let (mac, ipad) = SyncDevice.pair()
        var last: [CKRecord] = []
        for edit in 0..<(Encounter.sharedVersionLimit + 5) {
            mac.editNotes("Edit \(edit)")
            last = mac.upload()
        }
        ipad.download(last)
        #expect(ipad.encounterNames == ["A. Signal Jammer"])
    }

    @Test("Edits on both devices keep the newer and a conflict copy, which both devices share")
    func bothChanged() throws {
        let (mac, ipad) = SyncDevice.pair()
        ipad.editNotes("From the iPad")
        mac.editNotes("From the Mac")
        let attempt = try ipad.nextAttempt()
        let server = try #require(mac.upload().first)
        let refusal = CKError(.serverRecordChanged, userInfo: [CKRecordChangedErrorServerRecordKey: server])
        #expect(!ipad.sync.settle([(record: attempt, error: refusal)]))
        mac.download(ipad.upload())
        #expect(mac.encounterNames == ["A. Signal Jammer", "A. Signal Jammer (conflict copy)"])
        #expect(Set(mac.host.library.encounters.map(\.id)) == Set(ipad.host.library.encounters.map(\.id)))
        #expect(mac.pendingCount == 0 && ipad.pendingCount == 0)
    }

    @Test("The same edit made on both devices is not a conflict")
    func identicalEdits() {
        let (mac, ipad) = SyncDevice.pair()
        mac.editNotes("Goblin removed")
        ipad.editNotes("Goblin removed")
        ipad.download(mac.upload())
        #expect(ipad.encounterNames == ["A. Signal Jammer"])
        #expect(ipad.pendingCount == 0)
    }

    @Test("A first sync of libraries shared before falls back on their shared versions")
    func firstSync() {
        var macLibrary = Library(), ipadLibrary = Library()
        macLibrary.save(Encounter(scenarioID: UUID(), name: "A. Signal Jammer"))
        macLibrary = macLibrary.sending()
        LibraryMerger.merge(macLibrary, into: &ipadLibrary)
        var edited = macLibrary.encounters[0]
        edited.notes = "Edited on the Mac"
        macLibrary.save(edited)
        let mac = SyncDevice(), ipad = SyncDevice()
        mac.host.library = macLibrary
        ipad.host.library = ipadLibrary
        ipad.download(mac.upload())
        #expect(ipad.encounterNames == ["A. Signal Jammer"])
        #expect(ipad.host.library.encounters[0].notes == "Edited on the Mac")
    }

    @Test("An encounter arriving before its custom creature keeps its slot")
    func slotBeforeCreature() {
        let mac = SyncDevice(), ipad = SyncDevice()
        var encounter = Encounter(scenarioID: UUID(), name: "Ambush")
        var variant = EncounterVariant(label: "Base")
        variant.slots = [EncounterSlot(creatureKey: "custom.\(UUID().uuidString)")]
        encounter.variants = [variant]
        mac.host.library.save(encounter)
        ipad.download(mac.upload())
        #expect(ipad.host.library.encounters[0].variants[0].slots == variant.slots)
    }

    @Test("A change to the fight on screen waits until the GM leaves it")
    func activeFightHeld() {
        let mac = SyncDevice(), ipad = SyncDevice()
        let context = SessionContext(campaignID: UUID(), encounterID: UUID(), variantLabel: "Base", name: "Fight")
        mac.host.library.save(CombatSession(context: context, state: CombatState(combatants: [], events: [])))
        ipad.download(mac.upload())
        ipad.host.activeSessionID = ipad.host.library.sessions[0].id
        var session = mac.host.library.sessions[0]
        session.name = "Renamed elsewhere"
        mac.host.library.save(session)
        ipad.download(mac.upload())
        #expect(ipad.host.library.sessions[0].name == "Fight")
        ipad.host.activeSessionID = nil
        ipad.sync.releaseHeldRecords()
        #expect(ipad.host.library.sessions[0].name == "Renamed elsewhere")
    }

    @Test("A record in a later format is held, this device's copy isn't sent over it, and the app asks for an update")
    func laterFormat() throws {
        let (mac, ipad) = SyncDevice.pair()
        mac.editNotes("From a newer app")
        let record = try #require(mac.upload().first)
        record["format"] = CampaignRecordCoder.format + 1
        ipad.editNotes("From this device")
        ipad.download([record])
        #expect(ipad.host.library.encounters[0].notes == "From this device")
        #expect(ipad.pendingCount == 0)
        #expect(ipad.host.needsUpdateToSync && !mac.host.needsUpdateToSync)
        let relaunched = FakeSyncHost()
        _ = CampaignSync(host: relaunched, folder: ipad.folder)
        #expect(relaunched.needsUpdateToSync)
    }

    @Test("Records go up in the format that holds them back on versions from before the Society setting")
    func sendsFormat() throws {
        let (mac, _) = SyncDevice.pair()
        mac.editNotes("From this app")
        #expect(try #require(mac.upload().first)["format"] as? Int64 == 2)
    }

    @Test("The sync state survives a relaunch")
    func relaunch() {
        let (mac, _) = SyncDevice.pair()
        let again = CampaignSync(host: mac.host, folder: mac.folder)
        #expect(again.pendingChanges().isEmpty)
    }

    @Test("A merged party with the winner's stamp is still sent after a file import")
    func importedMerge() {
        let (mac, _) = SyncDevice.pair()
        #expect(mac.pendingCount == 0)
        var encounter = mac.host.library.encounters[0]
        encounter.notes = "Same stamp, new content"
        mac.host.library.encounters[0] = encounter
        #expect(mac.pendingCount == 0)
        mac.sync.libraryMerged()
        #expect(mac.pendingCount == 1)
    }

    @Test("Record names round-trip, and others aren't Turnkeeper's")
    func names() {
        let reference = CampaignRecordReference(kind: .creatureNote, id: UUID())
        #expect(CampaignRecordReference(recordName: reference.recordName) == reference)
        #expect(CampaignRecordReference(recordName: "pawn-\(UUID().uuidString)") == nil)
        #expect(CampaignRecordReference(recordName: "campaign-nope") == nil)
    }
}
