import Foundation
import Testing
@testable import TurnkeeperKit

@Suite("Society campaigns")
struct SocietyCampaignTests {
    private func encode(_ campaign: Campaign) throws -> Data { try JSONEncoder().encode(campaign) }

    @Test("A campaign saved before the Society setting reads as society with no Event ID")
    func oldCampaign() throws {
        var saved = try #require(JSONSerialization.jsonObject(with: encode(Campaign(name: "PFS 7", game: .pathfinder)))
                                 as? [String: Any])
        saved["isSociety"] = nil
        saved["eventID"] = nil
        let campaign = try JSONDecoder().decode(Campaign.self, from: JSONSerialization.data(withJSONObject: saved))
        #expect(campaign.isSociety)
        #expect(campaign.eventID.isEmpty)
    }

    @Test("The Society setting and Event ID round-trip")
    func roundTrip() throws {
        var campaign = Campaign(name: "Home game", game: .pathfinder, isSociety: false)
        campaign.eventID = "E-42"
        let copy = try JSONDecoder().decode(Campaign.self, from: encode(campaign))
        #expect(!copy.isSociety)
        #expect(copy.eventID == "E-42")
        #expect(copy.name == "Home game")
    }

    @Test("A new campaign is society unless said otherwise")
    func defaultsToSociety() {
        #expect(Campaign(name: "x", game: .starfinder).isSociety)
    }

    @Test("Wording and features follow the Society setting", arguments: [true, false])
    func wording(isSociety: Bool) {
        let campaign = Campaign(name: "x", game: .pathfinder, isSociety: isSociety)
        #expect(campaign.kindTitle == (isSociety ? "Event" : "Campaign"))
        #expect(campaign.scenarioTitle == (isSociety ? "Scenario" : "Adventure"))
        #expect(campaign.allowsMultipleParties == isSociety)
        #expect(campaign.allowsDifficultyVariants == isSociety)
    }

    @Test("Society scenarios are not offered One version")
    func schemeChoices() {
        #expect(!VariantScheme.societyChoices.contains(.single))
        #expect(VariantScheme.societyChoices.count == VariantScheme.allCases.count - 1)
    }

    @Test("The base difficulty is Base when the scenario has one, else the first")
    func baseVariant() {
        let campaignID = UUID()
        let three = Scenario(campaignID: campaignID, name: "x", variantLabels: VariantScheme.easierBaseHarder.labels)
        let tiers = Scenario(campaignID: campaignID, name: "x",
                             variantLabels: VariantScheme.challengePointsLowTier.labels)
        #expect(three.baseVariantLabel == "Base")
        #expect(tiers.baseVariantLabel == "8–9 CP")
        #expect(Scenario(campaignID: campaignID, name: "x").baseVariantLabel == "Standard")
    }

    @Test("Members saved before Society numbers read as blank, and the numbers round-trip")
    func memberNumbers() throws {
        let old = try JSONDecoder().decode(
            PartyMember.self, from: Data(#"{"id":"5A1C3A2E-0000-4000-8000-000000000004","name":"Ezren"}"#.utf8))
        #expect(old.societyID.isEmpty && old.characterNumber.isEmpty)
        var member = PartyMember(name: "Kyra")
        member.societyID = "123456"
        member.characterNumber = "2001"
        let copy = try JSONDecoder().decode(PartyMember.self, from: JSONEncoder().encode(member))
        #expect(copy.societyID == "123456" && copy.characterNumber == "2001")
    }
}
