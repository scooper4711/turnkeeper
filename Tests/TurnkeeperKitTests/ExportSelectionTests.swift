import Bestiary
import Foundation
import Testing
@testable import TurnkeeperKit

/// A campaign with two scenarios to pick from: the first has two encounters and a handout, and its first
/// encounter has a custom creature with pasted art and a note.
private struct PlannedCampaign {
    var library = Library()
    let campaign = Campaign(name: "PFS Season 7", game: .pathfinder)
    let docks: Scenario
    let vault: Scenario
    let ambush: Encounter
    let chase: Encounter
    let heist: Encounter
    let map: Handout
    let heroes: Party
    let rivals: Party
    let gwibble: CustomCreature

    init() {
        docks = Scenario(campaignID: campaign.id, name: "#7-03")
        vault = Scenario(campaignID: campaign.id, name: "#7-04")
        gwibble = CustomCreature(campaignID: campaign.id, game: .pathfinder, name: "Gwibble")
        ambush = Self.encounter("A: Ambush", in: docks, creatures: [gwibble.key, "goblin"])
        chase = Self.encounter("B: Chase", in: docks, creatures: ["wolf"])
        heist = Self.encounter("A: Heist", in: vault, creatures: ["dragon"])
        var map = Handout(scenarioID: docks.id, name: "Map of the Docks")
        map.fileName = "map.jpg"
        self.map = map
        heroes = Party(campaignID: campaign.id, name: "Heroes", level: 3, members: [PartyMember(name: "Ezren")])
        rivals = Party(campaignID: campaign.id, name: "Rivals", level: 5)
        library.save(campaign)
        [docks, vault].forEach { library.save($0) }
        [ambush, chase, heist].forEach { library.save($0) }
        library.save(map)
        [heroes, rivals].forEach { library.save($0) }
        library.save(gwibble)
        for subject in [gwibble.key, "wolf", "dragon", PlayerCharacter.key(for: heroes.members[0])] {
            library.save(CustomArt(subject: subject, fileName: "\(subject).jpg", byteCount: 1))
        }
        for subject in ["goblin", "wolf"] {
            library.save(CreatureNote(scenarioID: docks.id, subject: subject, text: "About the \(subject)"))
        }
    }

    private static func encounter(_ name: String, in scenario: Scenario, creatures: [String]) -> Encounter {
        var encounter = Encounter(scenarioID: scenario.id, name: name)
        var variant = encounter.variant(scenario.variantLabels[0])
        variant.slots = creatures.map(EncounterSlot.init(creatureKey:))
        encounter.setVariant(variant)
        return encounter
    }

    /// A selection of the campaign with these items checked.
    func selection(_ items: ExportItem...) -> ExportSelection {
        var selection = ExportSelection(campaignID: campaign.id)
        for item in items { selection.include(item, from: library) }
        return selection
    }
}

@Suite("Choosing what to export")
struct ExportSelectionTests {
    private let planned = PlannedCampaign()

    @Test("A scenario brings what's in it, and takes it along when cleared")
    func scenario() {
        var selection = planned.selection(.scenario(planned.docks))
        #expect(selection.contains(.scenario(planned.docks)) && !selection.contains(.scenario(planned.vault)))
        #expect(selection.encounterIDs == [planned.ambush.id, planned.chase.id])
        #expect(selection.contains(.handout(planned.map)) && !selection.contains(.party(planned.heroes)))
        selection.exclude(.scenario(planned.docks), from: planned.library)
        #expect(selection.isEmpty)
    }

    @Test("An encounter or a handout brings its scenario, and leaves it checked when cleared")
    func scenarioTravelsWithItsContents() {
        var selection = planned.selection(.encounter(planned.ambush))
        #expect(selection.scenarioIDs == [planned.docks.id] && selection.encounterIDs == [planned.ambush.id])
        #expect(!selection.contains(.encounter(planned.chase)) && selection.handoutIDs.isEmpty)
        selection.exclude(.encounter(planned.ambush), from: planned.library)
        #expect(selection.scenarioIDs == [planned.docks.id] && selection.encounterIDs.isEmpty)

        var handout = planned.selection(.handout(planned.map))
        #expect(handout.scenarioIDs == [planned.docks.id] && handout.handoutIDs == [planned.map.id])
        handout.exclude(.handout(planned.map), from: planned.library)
        #expect(handout.handoutIDs.isEmpty)
    }

    @Test("Parties are checked and cleared on their own")
    func parties() {
        var selection = planned.selection(.party(planned.heroes), .party(planned.rivals))
        #expect(selection.partyIDs == [planned.heroes.id, planned.rivals.id] && selection.scenarioIDs.isEmpty)
        selection.exclude(.party(planned.rivals), from: planned.library)
        #expect(selection.contains(.party(planned.heroes)) && !selection.contains(.party(planned.rivals)))
    }

    @Test("Everything checks all a campaign shows, and nothing clears it")
    func everything() {
        var selection = ExportSelection.everything(in: planned.campaign.id, of: planned.library)
        #expect(selection.id == planned.campaign.id)
        #expect(selection.scenarioIDs.count == 2 && selection.encounterIDs.count == 3)
        #expect(selection.handoutIDs.count == 1 && selection.partyIDs.count == 2)
        selection.excludeAll()
        #expect(selection.isEmpty && selection == ExportSelection(campaignID: planned.campaign.id))
    }

    @Test("Outside Society play, everything checks only the party the campaign shows")
    func homeCampaignParty() {
        var library = planned.library
        var campaign = planned.campaign
        campaign.isSociety = false
        library.save(campaign)
        let selection = ExportSelection.everything(in: campaign.id, of: library)
        #expect(selection.partyIDs == [planned.heroes.id])
    }

    @Test("The file is named for the one scenario, encounter or party it holds, else for the campaign")
    func fileName() {
        let library = planned.library
        #expect(planned.selection(.scenario(planned.docks)).fileName(in: library) == "#7-03.turnkeeper")
        #expect(planned.selection(.encounter(planned.ambush)).fileName(in: library)
                == "#7-03, A - Ambush.turnkeeper")
        #expect(planned.selection(.handout(planned.map)).fileName(in: library) == "#7-03.turnkeeper")
        #expect(planned.selection(.party(planned.heroes)).fileName(in: library) == "Heroes.turnkeeper")
        #expect(planned.selection(.encounter(planned.ambush), .party(planned.heroes)).fileName(in: library)
                == "PFS Season 7.turnkeeper")
        #expect(planned.selection(.scenario(planned.docks), .scenario(planned.vault)).fileName(in: library)
                == "PFS Season 7.turnkeeper")
        #expect(ExportSelection(campaignID: UUID()).fileName(in: library) == "Turnkeeper.turnkeeper")
        var slashed = library
        var party = planned.heroes
        party.name = "Heroes/Villains"
        slashed.save(party)
        #expect(planned.selection(.party(party)).fileName(in: slashed) == "Heroes-Villains.turnkeeper")
    }
}

@Suite("The exported part of a library")
struct ExportedLibraryTests {
    private let planned = PlannedCampaign()

    @Test("One encounter goes with its campaign and scenario and what its creatures need, and nothing else")
    func oneEncounter() {
        let exported = planned.library.exporting(planned.selection(.encounter(planned.ambush)))
        #expect(exported.campaigns.map(\.id) == [planned.campaign.id])
        #expect(exported.scenarios.map(\.id) == [planned.docks.id])
        #expect(exported.encounters.map(\.id) == [planned.ambush.id])
        #expect(exported.customCreatures.map(\.id) == [planned.gwibble.id])
        #expect(exported.customArt.map(\.subject) == [planned.gwibble.key])
        #expect(exported.creatureNotes.map(\.subject) == ["goblin"])
        #expect(exported.handouts.isEmpty && exported.parties.isEmpty)
    }

    @Test("A scenario goes with its encounters and handouts, and notes only on the creatures in them")
    func oneScenario() {
        let exported = planned.library.exporting(planned.selection(.scenario(planned.docks)))
        #expect(Set(exported.encounters.map(\.id)) == [planned.ambush.id, planned.chase.id])
        #expect(exported.handouts.map(\.id) == [planned.map.id])
        #expect(Set(exported.creatureNotes.map(\.subject)) == ["goblin", "wolf"])
        #expect(Set(exported.customArt.map(\.subject)) == [planned.gwibble.key, "wolf"])
        #expect(exported.liveImageFileNames.contains("map.jpg"))
    }

    @Test("A note on a creature goes only with the scenario it was written in")
    func notesStayInTheirScenario() {
        var library = planned.library
        library.save(CreatureNote(scenarioID: planned.docks.id, subject: "dragon", text: "Not in this scenario"))
        let exported = library.exporting(planned.selection(.encounter(planned.heist), .scenario(planned.docks)))
        #expect(!exported.creatureNotes.contains { $0.subject == "dragon" })
    }

    @Test("A party goes with its characters' portraits")
    func partyAlone() {
        let exported = planned.library.exporting(planned.selection(.party(planned.heroes)))
        #expect(exported.parties.map(\.id) == [planned.heroes.id])
        #expect(exported.customArt.map(\.subject) == [PlayerCharacter.key(for: planned.heroes.members[0])])
        #expect(exported.campaigns.count == 1 && exported.scenarios.isEmpty && exported.encounters.isEmpty)
    }

    @Test("Deleted records and saved fights stay out, and so does another campaign")
    func leftOut() {
        var library = planned.library
        library.save(Campaign(name: "Home game", game: .starfinder))
        let context = SessionContext(campaignID: planned.campaign.id, encounterID: planned.ambush.id,
                                     variantLabel: planned.docks.variantLabels[0], name: "A: Ambush")
        library.save(CombatSession(context: context, state: CombatState()))
        let everything = ExportSelection.everything(in: planned.campaign.id, of: library)
        library.deleteEncounter(planned.chase.id)
        library.deleteHandout(planned.map.id)
        library.deleteParty(planned.rivals.id)
        library.deleteCustomArt(for: "dragon")
        let exported = library.exporting(everything)
        #expect(exported.campaigns.map(\.name) == ["PFS Season 7"])
        #expect(Set(exported.encounters.map(\.id)) == [planned.ambush.id, planned.heist.id])
        #expect(exported.handouts.isEmpty && exported.parties.map(\.id) == [planned.heroes.id])
        #expect(!exported.customArt.contains { $0.subject == "dragon" || $0.subject == "wolf" })
        #expect(exported.sessions.isEmpty)
    }

    @Test("An exported encounter lands in its scenario and campaign on a device that has neither")
    func importsWhereItBelongs() throws {
        let package = LibraryPackage(picking: planned.selection(.encounter(planned.ambush)), from: planned.library,
                                     bestiaryRevision: "abc")
        var received = Library()
        let summary = LibraryMerger.merge(try LibraryPackage.decode(package.encoded()).library, into: &received)
        #expect(summary.added == 6 && summary.conflicts == 0)
        #expect(received.activeCampaigns.map(\.name) == ["PFS Season 7"])
        #expect(received.scenarios(in: planned.campaign.id).map(\.name) == ["#7-03"])
        #expect(received.encounters(in: planned.docks.id).map(\.name) == ["A: Ambush"])
        #expect(received.customCreature(key: planned.gwibble.key) != nil)
    }
}
