import Bestiary
import Foundation

/// Creatures the plan left out, added while the fight runs.
public extension CombatState {
    /// Adds a bestiary or custom creature as an enemy at the end of the order, with no initiative yet: the GM
    /// rolls and enters one, as for a creature brought in from the bench. Returns the new combatant's ID.
    @discardableResult
    mutating func addCreature(_ entry: BestiaryIndexEntry) -> UUID {
        let kind: CombatantKind = entry.kind == .hazard ? .hazard : .creature
        let combatant = Combatant(kind: kind, name: nextName(for: entry.name), creatureKey: entry.key)
        combatants.append(combatant)
        order.append(combatant.id)
        // A fight begun with an empty ladder has nobody acting; the newcomer takes the turn.
        if phase == .active, currentID == nil { currentID = combatant.id }
        return combatant.id
    }

    /// The name alone when nobody in the fight has it; otherwise the number after the highest in the fight,
    /// so a second "Goblin" is "Goblin 2" and nobody already on the board is renamed.
    private func nextName(for name: String) -> String {
        let numbers = combatants.compactMap { number(of: $0.name, named: name) }
        return numbers.max().map { "\(name) \($0 + 1)" } ?? name
    }

    /// 1 for the bare name, 3 for "Goblin 3", nil for anyone else, "Goblin Warrior 3" included.
    private func number(of combatantName: String, named name: String) -> Int? {
        if combatantName == name { return 1 }
        guard combatantName.hasPrefix(name + " ") else { return nil }
        return Int(combatantName.dropFirst(name.count + 1))
    }
}
