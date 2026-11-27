import Foundation

/// A line of the export dialog: something the GM can check to put it in a `.turnkeeper` file.
public enum ExportItem: Sendable {
    case scenario(Scenario)
    case encounter(Encounter)
    case handout(Handout)
    case party(Party)
}

/// What the GM checked to export from one campaign (R1.2a).
public struct ExportSelection: Sendable, Equatable, Identifiable {
    public let campaignID: UUID
    /// The scenarios that go in the file. A checked encounter's or handout's scenario is always one of them, as
    /// that is where an import puts it.
    public private(set) var scenarioIDs: Set<UUID> = []
    public private(set) var encounterIDs: Set<UUID> = []
    public private(set) var handoutIDs: Set<UUID> = []
    public private(set) var partyIDs: Set<UUID> = []

    public init(campaignID: UUID) {
        self.campaignID = campaignID
    }

    /// Everything the campaign shows, checked.
    public static func everything(in campaignID: UUID, of library: Library) -> ExportSelection {
        var selection = ExportSelection(campaignID: campaignID)
        selection.includeAll(from: library)
        return selection
    }

    public var id: UUID { campaignID }

    public var isEmpty: Bool {
        scenarioIDs.isEmpty && encounterIDs.isEmpty && handoutIDs.isEmpty && partyIDs.isEmpty
    }

    public func contains(_ item: ExportItem) -> Bool {
        switch item {
        case let .scenario(scenario): scenarioIDs.contains(scenario.id)
        case let .encounter(encounter): encounterIDs.contains(encounter.id)
        case let .handout(handout): handoutIDs.contains(handout.id)
        case let .party(party): partyIDs.contains(party.id)
        }
    }

    /// The name for the file: the one scenario, encounter or party it holds, else the campaign. Finder shows a
    /// colon in a file's name as a slash, and a slash can't be in one.
    public func fileName(in library: Library) -> String {
        let name = title(in: library)
            .replacingOccurrences(of: ":", with: " -")
            .replacingOccurrences(of: "/", with: "-")
        return name + ".turnkeeper"
    }

    /// Checks an item. A scenario brings its encounters and handouts along, and an encounter or a handout
    /// brings its scenario.
    public mutating func include(_ item: ExportItem, from library: Library) {
        switch item {
        case let .scenario(scenario):
            scenarioIDs.insert(scenario.id)
            encounterIDs.formUnion(library.encounters(in: scenario.id).map(\.id))
            handoutIDs.formUnion(library.handouts(in: scenario.id).map(\.id))
        case let .encounter(encounter):
            scenarioIDs.insert(encounter.scenarioID)
            encounterIDs.insert(encounter.id)
        case let .handout(handout):
            scenarioIDs.insert(handout.scenarioID)
            handoutIDs.insert(handout.id)
        case let .party(party):
            partyIDs.insert(party.id)
        }
    }

    /// Clears an item's check mark. A scenario takes its encounters and handouts along.
    public mutating func exclude(_ item: ExportItem, from library: Library) {
        switch item {
        case let .scenario(scenario):
            scenarioIDs.remove(scenario.id)
            encounterIDs.subtract(library.encounters(in: scenario.id).map(\.id))
            handoutIDs.subtract(library.handouts(in: scenario.id).map(\.id))
        case let .encounter(encounter):
            encounterIDs.remove(encounter.id)
        case let .handout(handout):
            handoutIDs.remove(handout.id)
        case let .party(party):
            partyIDs.remove(party.id)
        }
    }

    /// Checks every scenario, with what's in it, and every party the campaign shows.
    public mutating func includeAll(from library: Library) {
        for scenario in library.scenarios(in: campaignID) { include(.scenario(scenario), from: library) }
        partyIDs.formUnion(library.shownParties(in: campaignID).map(\.id))
    }

    public mutating func excludeAll() {
        self = ExportSelection(campaignID: campaignID)
    }

    private func title(in library: Library) -> String {
        if partyIDs.isEmpty, scenarioIDs.count == 1,
           let scenario = library.scenarios.first(where: { scenarioIDs.contains($0.id) }) {
            return ([scenario.name] + loneEncounterName(in: library)).joined(separator: ", ")
        }
        if scenarioIDs.isEmpty, partyIDs.count == 1,
           let party = library.parties.first(where: { partyIDs.contains($0.id) }) {
            return party.name
        }
        return library.campaigns.first { $0.id == campaignID }?.name ?? "Turnkeeper"
    }

    /// The encounter's name when one encounter is all that's checked in its scenario, else nothing.
    private func loneEncounterName(in library: Library) -> [String] {
        guard encounterIDs.count == 1, handoutIDs.isEmpty else { return [] }
        return library.encounters.filter { encounterIDs.contains($0.id) }.map(\.name)
    }
}

public extension Library {
    /// The part of the library a selection names, for a file: the campaign, the checked scenarios, encounters,
    /// handouts and parties, and what those use (the encounters' custom creatures, their pasted art and the notes
    /// on their creatures, and the portraits of the parties' characters). Deleted records and fights stay out.
    func exporting(_ selection: ExportSelection) -> Library {
        var subset = Library()
        subset.campaigns = campaigns.filter { $0.id == selection.campaignID && !$0.isDeleted }
        subset.parties = parties.filter { selection.partyIDs.contains($0.id) && !$0.isDeleted }
        subset.scenarios = scenarios.filter { selection.scenarioIDs.contains($0.id) && !$0.isDeleted }
        subset.encounters = encounters.filter { selection.encounterIDs.contains($0.id) && !$0.isDeleted }
        subset.handouts = handouts.filter { selection.handoutIDs.contains($0.id) && !$0.isDeleted }
        let creatures = Dictionary(grouping: subset.encounters, by: \.scenarioID).mapValues(Self.creatureKeys(in:))
        subset.creatureNotes = creatureNotes.filter { note in
            !note.isDeleted && creatures[note.scenarioID]?.contains(note.subject) == true
        }
        let creatureKeys = creatures.values.reduce(into: Set<String>()) { $0.formUnion($1) }
        subset.customCreatures = customCreatures.filter { creatureKeys.contains($0.key) && !$0.isDeleted }
        let subjects = creatureKeys.union(subset.parties.flatMap(\.members).map(PlayerCharacter.key(for:)))
        subset.customArt = customArt.filter { subjects.contains($0.subject) && !$0.isDeleted }
        return subset
    }

    /// The keys of every creature in any difficulty of the encounters.
    private static func creatureKeys(in encounters: [Encounter]) -> Set<String> {
        Set(encounters.flatMap { $0.variants.flatMap { $0.slots.map(\.creatureKey) } })
    }
}
