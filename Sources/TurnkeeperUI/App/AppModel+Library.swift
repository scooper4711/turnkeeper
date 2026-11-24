import Bestiary
import TurnkeeperKit
import Foundation

/// What the campaign sheet collects for a new campaign.
struct NewCampaign {
    var name: String
    var game: Game
    var isSociety: Bool
    var eventID = ""
}

/// Planning changes: campaigns, parties, scenarios and encounters.
extension AppModel {
    @discardableResult
    func addCampaign(_ new: NewCampaign) -> Campaign {
        var campaign = Campaign(name: new.name, game: new.game, isSociety: new.isSociety)
        campaign.eventID = new.eventID
        library.save(campaign)
        // A campaign outside organized play has exactly one party, so it starts with it.
        if !new.isSociety { makeParty(in: campaign.id) }
        selectedCampaignID = campaign.id
        selection = nil
        return campaign
    }

    func deleteCampaign(_ id: UUID) {
        library.deleteCampaign(id)
        if selectedCampaignID == id { selectedCampaignID = library.activeCampaign(preferring: nil)?.id }
        selection = nil
    }

    func addParty(to campaignID: UUID) {
        selection = .party(makeParty(in: campaignID).id)
    }

    @discardableResult
    private func makeParty(in campaignID: UUID) -> Party {
        let party = Party(campaignID: campaignID, name: "New party", level: 1,
                          members: (1...4).map { PartyMember(name: PartyMember.placeholderName(number: $0)) })
        library.save(party)
        return party
    }

    func addScenario(to campaignID: UUID, name: String, labels: [String]) {
        // Outside organized play there is one version of each adventure, whatever labels came in.
        let isSociety = campaign(campaignID)?.isSociety ?? true
        var scenario = Scenario(campaignID: campaignID, name: name,
                                variantLabels: isSociety ? labels : VariantScheme.single.labels)
        scenario.sortIndex = (library.scenarios(in: campaignID).map(\.sortIndex).max() ?? 0) + 1
        library.save(scenario)
        selection = .scenario(scenario.id)
    }

    func addEncounter(to scenarioID: UUID) {
        let existing = library.encounters(in: scenarioID)
        let letter = existing.count < 26 ? String(UnicodeScalar(UInt8(65 + existing.count))) : "\(existing.count + 1)"
        var encounter = Encounter(scenarioID: scenarioID, name: "Encounter \(letter)")
        encounter.sortIndex = (existing.map(\.sortIndex).max() ?? 0) + 1
        library.save(encounter)
        selection = .encounter(encounter.id)
    }

    func campaign(_ id: UUID?) -> Campaign? {
        library.campaigns.first { $0.id == id && !$0.isDeleted }
    }

    func party(_ id: UUID?) -> Party? {
        library.parties.first { $0.id == id && !$0.isDeleted }
    }

    /// A party member by ID, from any party; members are unique across parties.
    func partyMember(_ id: UUID) -> PartyMember? {
        library.parties.lazy.filter { !$0.isDeleted }.flatMap(\.members).first { $0.id == id }
    }

    func scenario(_ id: UUID?) -> Scenario? {
        library.scenarios.first { $0.id == id && !$0.isDeleted }
    }

    func encounter(_ id: UUID?) -> Encounter? {
        library.encounters.first { $0.id == id && !$0.isDeleted }
    }

    /// The parties a campaign shows: all in Society play, else the first. Hidden ones are kept, not deleted.
    func shownParties(in campaignID: UUID) -> [Party] {
        let parties = library.parties(in: campaignID)
        return campaign(campaignID)?.allowsMultipleParties == false ? Array(parties.prefix(1)) : parties
    }

    /// The party used for budgets: the campaign's first party, if any.
    func defaultParty(for campaignID: UUID?) -> Party? {
        campaignID.flatMap { library.parties(in: $0).first }
    }
}
