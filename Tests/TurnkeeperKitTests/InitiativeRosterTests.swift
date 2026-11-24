import Bestiary
import Foundation
import Testing
@testable import TurnkeeperKit

@Suite("The voice initiative screen's rows")
struct InitiativeRosterTests {
    private func pc(_ name: String, member: UUID? = UUID()) -> Combatant {
        var pc = Combatant(kind: .playerCharacter, name: name)
        pc.memberID = member
        return pc
    }

    private func creature(_ name: String, key: String, template: CreatureTemplate = .normal,
                          kind: CombatantKind = .creature) -> Combatant {
        var creature = Combatant(kind: kind, name: name, creatureKey: key)
        creature.template = template
        return creature
    }

    private func roster(_ state: CombatState, seating: [UUID] = [], showsAll: Bool = false,
                        ranks: [String: Int] = [:]) -> InitiativeRoster {
        InitiativeRoster(state: state, seating: seating, showsAll: showsAll) { ranks[$0.name] ?? 0 }
    }

    @Test("PCs follow the seating order; unseated ones come last, in setup order")
    func seatingOrder() {
        let pcs = ["Kyra", "Ezren", "Merisiel", "Valeros"].map { pc($0) }
        let state = CombatState(combatants: pcs + [creature("Goblin", key: "goblin")])
        let seating = [pcs[2], pcs[0]].compactMap(\.memberID)
        #expect(roster(state, seating: seating).rows.map(\.name) == ["Merisiel", "Kyra", "Ezren", "Valeros"])
    }

    @Test("A PC from a session saved before member links finds its seat by its key")
    func oldSession() {
        let member = UUID()
        var old = pc("Valeros", member: nil)
        old.creatureKey = PlayerCharacter.key(memberID: member)
        let state = CombatState(combatants: [pc("Kyra"), old])
        #expect(roster(state, seating: [member]).rows.map(\.name) == ["Valeros", "Kyra"])
    }

    @Test("The bench stays out")
    func bench() {
        var away = pc("Ezren")
        away.place = .bench
        #expect(roster(CombatState(combatants: [pc("Kyra"), away])).rows.map(\.name) == ["Kyra"])
    }

    @Test("Show all adds creatures by rank, the same kind and template together")
    func showAll() {
        let state = CombatState(combatants: [
            creature("Goblin 1", key: "goblin"), creature("Dog", key: "dog"), pc("Kyra"),
            creature("Goblin 2", key: "goblin", template: .elite), creature("Goblin 3", key: "goblin"),
            creature("Pit", key: "pit", kind: .hazard)
        ])
        let ranks = ["Goblin 1": 5, "Goblin 2": 5, "Goblin 3": 5, "Dog": 7, "Pit": 2]
        #expect(roster(state, ranks: ranks).rows.map(\.name) == ["Kyra"])
        #expect(roster(state, showsAll: true, ranks: ranks).rows.map(\.name)
                == ["Kyra", "Dog", "Goblin 2", "Goblin 1", "Goblin 3", "Pit"])
    }

    @Test("The next open row goes down, wraps, and is nil once everyone has one")
    func nextOpen() {
        var state = CombatState(combatants: ["Kyra", "Ezren", "Merisiel"].map { pc($0) })
        let ids = roster(state).rows.map(\.id)
        #expect(roster(state).firstOpen == ids[0])
        state.setInitiative(15, for: ids[0])
        #expect(roster(state).nextOpen(after: ids[2]) == ids[1])
        #expect(roster(state).nextOpen(after: ids[1]) == ids[2])
        #expect(roster(state).nextOpen(after: UUID()) == ids[1])
        state.setInitiative(12, for: ids[1])
        state.setInitiative(9, for: ids[2])
        #expect(roster(state).nextOpen(after: ids[0]) == nil)
        #expect(roster(state).firstOpen == nil)
    }

    @Test("Of two Bobs, the first seated without an initiative, else the first seated")
    func pick() {
        let bobs = [pc("Bob"), pc("Bob the Barbarian")]
        var state = CombatState(combatants: bobs)
        let seating = [bobs[1], bobs[0]].compactMap(\.memberID)
        let both = bobs.map(\.id)
        #expect(roster(state, seating: seating).pick(both) == bobs[1].id)
        state.setInitiative(14, for: bobs[1].id)
        #expect(roster(state, seating: seating).pick(both) == bobs[0].id)
        state.setInitiative(11, for: bobs[0].id)
        #expect(roster(state, seating: seating).pick(both) == bobs[1].id)
        #expect(roster(state).pick([UUID()]) == nil)
    }

    @Test("Moving a PC row changes the seating; players away keep their seats, and new ones are seated")
    func move() {
        let pcs = ["Kyra", "Ezren", "Merisiel"].map { pc($0) }
        let members = pcs.compactMap(\.memberID)
        let away = UUID()
        let seating = [members[0], away, members[1]]  // Merisiel isn't seated yet.
        let rows = roster(CombatState(combatants: pcs), seating: seating)
        #expect(rows.seating(afterMoving: [2], to: 0, in: seating) == [members[2], away, members[0], members[1]])
        #expect(rows.seating(afterMoving: [0], to: 2, in: seating) == [members[1], away, members[0], members[2]])
    }
}
