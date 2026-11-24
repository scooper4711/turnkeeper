import Bestiary
import TurnkeeperKit
import Foundation

/// Planning changes: campaigns, parties, scenarios and encounters.
extension AppModel {
    @discardableResult
    func addCampaign(_ campaign: Campaign) -> Campaign {
        library.save(campaign)
        // A campaign outside organized play has exactly one party, so it starts with it.
        if !campaign.allowsMultipleParties { makeParty(in: campaign.id) }
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
        var scenario = Scenario(campaignID: campaignID, name: name,
                                variantLabels: isSociety(campaignID) ? labels : VariantScheme.single.labels)
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
        library.shownParties(in: campaignID)
    }

    /// Whether a campaign is Society play; one that can't be found counts as it.
    func isSociety(_ campaignID: UUID?) -> Bool {
        library.isSociety(campaignID)
    }

    /// The difficulties a scenario shows: all of them in Society play, else its base one. The rest are kept.
    func shownVariantLabels(of scenario: Scenario) -> [String] {
        isSociety(scenario.campaignID) ? scenario.variantLabels : [scenario.baseVariantLabel]
    }

    /// The party used for budgets: the campaign's first party, if any.
    func defaultParty(for campaignID: UUID?) -> Party? {
        campaignID.flatMap { library.parties(in: $0).first }
    }
}
