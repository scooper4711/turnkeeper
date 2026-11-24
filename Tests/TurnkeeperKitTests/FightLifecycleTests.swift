import Bestiary
import Foundation
import Testing
@testable import TurnkeeperKit

@Suite("Fight lifecycle")
struct FightLifecycleTests {
    private func combatant(_ name: String, _ kind: CombatantKind = .creature, side: Side = .enemy,
                           place: PadPlace = .ladder) -> Combatant {
        var combatant = Combatant(kind: kind, name: name, side: side)
        combatant.place = place
        return combatant
    }

    @Test("A fight has started once someone has initiative or combat has begun")
    func hasStarted() {
        var state = CombatState(combatants: [combatant("Orc")])
        #expect(!state.hasStarted)
        state.setInitiative(12, for: state.combatants[0].id)
        #expect(state.hasStarted)
    }

    @Test("Only ladder combatants without initiative are listed, in ladder order")
    func missingInitiative() {
        let kyra = combatant("Kyra", .playerCharacter)
        let orc = combatant("Orc")
        let wolf = combatant("Wolf", place: .bench)
        var state = CombatState(combatants: [kyra, orc, wolf])
        state.setInitiative(15, for: orc.id)
        #expect(state.combatantsWithoutInitiative.map(\.name) == ["Kyra"])
    }

    @Test("Victory needs every joined enemy at 0 HP; the bench, hazards and allies don't count")
    func allEnemiesDown() {
        var orc = combatant("Orc")
        orc.damageTaken = 20
        var goblin = combatant("Goblin")
        goblin.isDelaying = true
        goblin.damageTaken = 6
        let reserve = combatant("Reserve", place: .bench)
        let pit = combatant("Pit", .hazard)
        let guide = combatant("Guide", side: .ally)
        let state = CombatState(combatants: [orc, goblin, reserve, pit, guide])
        #expect(state.allEnemiesDown { $0.name == "Orc" ? 20 : 6 })
        #expect(!state.allEnemiesDown { _ in 30 })
        #expect(!CombatState(combatants: [guide]).allEnemiesDown { _ in 1 })
    }

    @Test("Finished and in-progress sessions, and the lookup for the unfinished one")
    func sessions() {
        let encounterID = UUID()
        let context = SessionContext(campaignID: UUID(), encounterID: encounterID, variantLabel: "Base", name: "A")
        var session = CombatSession(context: context, state: CombatState(combatants: [combatant("Orc")]))
        #expect(!session.isInProgress)
        session.state.setInitiative(10, for: session.state.combatants[0].id)
        #expect(session.isInProgress)
        var library = Library()
        library.save(session)
        #expect(library.unfinishedSession(encounterID: encounterID, variantLabel: "Base")?.id == session.id)
        #expect(library.unfinishedSession(encounterID: encounterID, variantLabel: "Harder") == nil)
        session.finishedAt = Date()
        library.save(session)
        #expect(library.unfinishedSession(encounterID: encounterID, variantLabel: "Base") == nil)
    }

    @Test("Sessions saved before finishing existed still decode, as unfinished")
    func decodesOldSessions() throws {
        let context = SessionContext(campaignID: UUID(), encounterID: UUID(), variantLabel: "Base", name: "A")
        let session = CombatSession(context: context, state: CombatState())
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(session)) as? [String: Any] ?? [:]
        json.removeValue(forKey: "finishedAt")
        json.removeValue(forKey: "partyID")
        let decoded = try JSONDecoder().decode(CombatSession.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(!decoded.isFinished)
    }
}

@Suite("Adding a creature during a fight")
struct AddingCreatureTests {
    private func entry(_ name: String, kind: CreatureKind = .creature) -> BestiaryIndexEntry {
        var creature = Creature(key: name.lowercased(), name: name, game: .pathfinder)
        creature.kind = kind
        return BestiaryIndexEntry(creature: creature)
    }

    @Test("A new creature joins as an enemy at the end of the order, without an initiative or a change of turn")
    func joinsAtTheEnd() {
        var (state, ids) = fight()
        let wolf = state.addCreature(entry("Wolf"))
        #expect(state.order == ids + [wolf])
        #expect(state.currentID == ids[0])
        #expect(state[wolf]?.name == "Wolf" && state[wolf]?.creatureKey == "wolf")
        #expect(state[wolf]?.side == .enemy && state[wolf]?.place == .ladder)
        #expect(state.combatantsWithoutInitiative.map(\.id) == [wolf])
    }

    @Test("Reinforcements join as allies: green, and no part of whether every enemy is down")
    func allies() {
        var (state, _) = fight()
        let guardID = state.addCreature(entry("Guard"), side: .ally)
        #expect(state[guardID]?.side == .ally && state[guardID]?.magnet == .green)
        for id in state.order where id != guardID { state[id]?.damageTaken = 10 }
        #expect(state.allEnemiesDown { _ in 10 })
    }

    @Test("It is numbered after those of its kind in the fight, and nobody is renamed")
    func numbering() {
        var (state, ids) = fight()
        let second = state.addCreature(entry("Goblin"))
        state.remove(second)
        let third = state.addCreature(entry("Goblin"))
        let fourth = state.addCreature(entry("Goblin"))
        #expect(state[ids[0]]?.name == "Goblin")
        #expect([third, fourth].map { state[$0]?.name } == ["Goblin 2", "Goblin 3"])
    }

    @Test("A longer name that starts the same way doesn't share the numbering")
    func otherKinds() {
        var state = CombatState(combatants: [Combatant(kind: .creature, name: "Goblin Warrior 3")])
        let goblin = state.addCreature(entry("Goblin"))
        #expect(state[goblin]?.name == "Goblin")
    }

    @Test("A hazard joins as a hazard, and takes the turn in a fight begun with nobody in it")
    func hazardInAnEmptyFight() {
        var state = CombatState()
        state.beginCombat()
        let pit = state.addCreature(entry("Drowning Pit", kind: .hazard))
        #expect(state[pit]?.kind == .hazard)
        #expect(state.currentID == pit)
    }

    @Test("In setup it joins the ladder and sorts into place once it has an initiative")
    func duringSetup() {
        var state = CombatState(combatants: [Combatant(kind: .playerCharacter, name: "Kyra")])
        let wolf = state.addCreature(entry("Wolf"))
        state.setInitiative(15, for: wolf)
        #expect(state.order.first == wolf && state.currentID == nil)
    }
}
