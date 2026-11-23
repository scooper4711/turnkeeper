import CloudKit
import Foundation
import Testing
@testable import TurnkeeperKit

@MainActor
@Suite("What's left inside a deleted campaign")
struct CampaignSyncOrphanTests {
    private let campaign: Campaign
    private let scenario: Scenario

    init() {
        campaign = Campaign(name: "Sync Test", game: .pathfinder)
        scenario = Scenario(campaignID: campaign.id, name: "7-03", variantLabels: ["Low"])
    }

    /// Two devices in step, both holding a campaign with one scenario.
    private func devices() -> (mac: SyncDevice, ipad: SyncDevice) {
        let mac = SyncDevice(), ipad = SyncDevice()
        mac.host.library.save(campaign)
        mac.host.library.save(scenario)
        ipad.download(mac.upload())
        return (mac, ipad)
    }

    private func isEncounterDeleted(_ id: UUID, on device: SyncDevice) -> Bool {
        device.host.library.encounters.contains { $0.id == id && $0.isDeleted }
    }

    @Test("A record made elsewhere before the delete arrived is deleted on both devices")
    func lateRecord() {
        let (mac, ipad) = devices()
        let late = Encounter(scenarioID: scenario.id, name: "Encounter A iPad")
        ipad.host.library.save(late)
        mac.host.library.deleteCampaign(campaign.id)

        ipad.download(mac.upload())
        mac.download(ipad.upload())

        #expect(isEncounterDeleted(late.id, on: ipad))
        #expect(isEncounterDeleted(late.id, on: mac))
        #expect(mac.pendingCount == 0 && ipad.pendingCount == 0)
    }

    @Test("Two devices retiring the same record agree, with no conflict copy")
    func bothRetire() {
        let (mac, ipad) = devices()
        let orphan = Encounter(scenarioID: scenario.id, name: "Encounter A")
        mac.host.library.save(orphan)
        ipad.download(mac.upload())
        mac.host.library.deleteCampaign(campaign.id)
        ipad.host.library.deleteCampaign(campaign.id)

        ipad.download(mac.upload())

        #expect(ipad.host.library.encounters.count == 1)
        #expect(ipad.host.library.encounters[0].isDeleted)
    }

    @Test("Leftovers from an earlier sync are deleted at the next start, and go up")
    func leftovers() throws {
        let (mac, _) = devices()
        mac.host.library.save(Encounter(scenarioID: scenario.id, name: "Survivor"))
        _ = mac.upload()
        var library = mac.host.library
        let index = try #require(library.campaigns.firstIndex { $0.id == campaign.id })
        library.campaigns[index].deletedAt = Date()
        mac.host.library = library

        mac.sync.retireOrphans()

        let live = mac.host.library.scenarios.filter { !$0.isDeleted }.count
            + mac.host.library.encounters.filter { !$0.isDeleted }.count
        #expect(live == 0)
        #expect(mac.pendingCount == 3)
    }

    @Test("The fight on screen survives until the GM leaves it")
    func activeFight() throws {
        var library = Library()
        library.save(campaign)
        let context = SessionContext(campaignID: campaign.id, encounterID: UUID(), variantLabel: "Low", name: "Fight")
        let fight = CombatSession(context: context, state: CombatState())
        library.save(fight)
        let index = try #require(library.campaigns.firstIndex { $0.id == campaign.id })
        library.campaigns[index].deletedAt = Date()

        let retiredDuringFight = library.retireOrphans(keepingSession: fight.id)
        #expect(!retiredDuringFight)
        #expect(library.sessions[0].deletedAt == nil)
        let retiredAfterFight = library.retireOrphans(keepingSession: nil)
        #expect(retiredAfterFight)
        #expect(library.sessions[0].deletedAt == library.campaigns[index].deletedAt)
    }
}
