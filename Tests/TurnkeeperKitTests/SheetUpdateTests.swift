import Bestiary
import Foundation
import Testing
@testable import TurnkeeperKit

@Suite("Applying imported sheets")
struct SheetUpdateTests {
    private let link = CharacterLink(source: .demiplane, characterID: "eagan", game: .starfinder, revision: "r1")

    private func sheet(armorClass: Int = 18, level: Int = 1) -> Creature {
        var sheet = Creature(key: "", name: "Eagan Norr (v.2)", game: .starfinder)
        sheet.level = level
        sheet.defenses.armorClass = armorClass
        return sheet
    }

    private func linkedParty() -> (party: Party, memberID: UUID) {
        var party = Party(campaignID: UUID(), name: "Friday", level: 1)
        var member = PartyMember(name: "Eagan Norr")
        member.sheet = sheet()
        member.link = link
        member.maxHitPoints = 20
        party.members.append(member)
        return (party, member.id)
    }

    @Test("A new character joins as a new member under its sheet's name")
    func added() {
        var party = Party(campaignID: UUID(), name: "Friday", level: 1)
        #expect(party.apply(sheet(), link: link) == .added)
        #expect(party.members.map(\.name) == ["Eagan Norr (v.2)"] && party.members[0].link == link)
    }

    @Test("A rebuild reports what changed and keeps the member's name and max HP")
    func updated() {
        var (party, memberID) = linkedParty()
        var newLink = link
        newLink.revision = "r2"
        var rebuilt = sheet(armorClass: 19, level: 2)
        rebuilt.items = ["Rotating Pistol"]
        #expect(party.apply(rebuilt, link: newLink, to: memberID) == .updated(["Level 1 → 2", "AC 18 → 19", "items"]))
        let member = party.members[0]
        #expect(party.members.count == 1 && member.name == "Eagan Norr" && member.maxHitPoints == 20)
        #expect(member.level == 2 && member.link?.revision == "r2" && member.sheet == rebuilt)
    }

    @Test("The same sheet again is unchanged, matched by its character without a member ID")
    func unchanged() {
        var (party, _) = linkedParty()
        #expect(party.apply(sheet(), link: link) == .unchanged)
        #expect(party.members.count == 1)
    }

    @Test("Linking a quick PC is an update with nothing to compare")
    func linkingQuickPC() {
        var party = Party(campaignID: UUID(), name: "Friday", level: 1)
        let quick = PartyMember(name: "Eagan")
        party.members.append(quick)
        #expect(party.apply(sheet(), link: link, to: quick.id) == .updated([]))
        #expect(party.members.count == 1 && party.members[0].name == "Eagan" && party.members[0].sheet != nil)
    }

    @Test("Linking a member still called Player 1 gives it the character's name")
    func linkingPlaceholder() {
        var party = Party(campaignID: UUID(), name: "Friday", level: 1)
        let placeholder = PartyMember(name: PartyMember.placeholderName(number: 1))
        party.members.append(placeholder)
        #expect(party.apply(sheet(), link: link, to: placeholder.id) == .updated([]))
        #expect(party.members[0].name == "Eagan Norr (v.2)")
    }

    @Test("Refreshing an unchanged sheet still replaces a placeholder left by an earlier import")
    func refreshingPlaceholder() {
        var (party, memberID) = linkedParty()
        party.members[0].name = PartyMember.placeholderName(number: 1)
        #expect(party.apply(sheet(), link: link, to: memberID) == .updated([]))
        #expect(party.members[0].name == "Eagan Norr (v.2)")
    }

    @Test("Only the exact placeholder pattern counts as unnamed", arguments: [
        ("Player 1", true), ("Player 12", true), ("Player One", false), ("Player", false), ("Player 1 Bob", false)
    ])
    func placeholderPattern(name: String, isPlaceholder: Bool) {
        #expect(PartyMember(name: name).hasPlaceholderName == isPlaceholder)
    }
}
