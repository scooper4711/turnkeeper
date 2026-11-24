import Bestiary
import Foundation
import TurnkeeperKit

/// The voice initiative screen's side of the board: its rows, the party's seating order, and spoken totals.
extension BoardController {

    /// The party the fight was started with.
    var party: Party? { model.party(session?.partyID) }

    /// The screen's rows: PCs in seating order, then with `showsAll` the creatures, by Perception.
    func voiceRoster(showsAll: Bool) -> InitiativeRoster {
        InitiativeRoster(state: state, seating: party?.seating ?? [], showsAll: showsAll) { rank(of: $0) }
    }

    /// The names that select each row: the character's and the player's.
    func spokenNames(of rows: [Combatant]) -> SpokenNameMatcher {
        SpokenNameMatcher(candidates: rows.map { ($0.id, [$0.name, $0.playerName].filter { !$0.isEmpty }) })
    }

    /// Saves the party's seating after PC rows are dragged. The initiative order doesn't change.
    func moveSeat(from source: IndexSet, to destination: Int) {
        guard var party else { return }
        party.seating = voiceRoster(showsAll: false).seating(afterMoving: source, to: destination, in: party.seating)
        model.library.save(party)
    }

    /// Records a spoken total, adding the natural bonus for "nat 17", and returns what was recorded. It can be
    /// undone like any other change.
    func recordSpoken(_ heard: SpokenInitiative, for id: UUID) -> Double {
        let bonus = heard.isNatural ? state[id].flatMap(naturalBonus(for:)) ?? 0 : 0
        let value = heard.value + Double(bonus)
        change { $0.setInitiative(value, for: id) }
        return value
    }

    /// What "nat X" adds: the higher of Perception and Stealth, from a creature's stat block or a linked PC's
    /// sheet. Nil for a quick PC or an unknown creature.
    func naturalBonus(for combatant: Combatant) -> Int? {
        guard let creature = creature(for: combatant) else { return nil }
        let presenter = StatBlockPresenter(creature: creature, template: combatant.template,
                                           conditions: combatant.conditions)
        let stealth = creature.kind == .hazard ? presenter.initiative.value
            : creature.skills.first { $0.name == "Stealth" }.map { presenter.skill($0).value }
        return max(presenter.perception.value, stealth ?? .min)
    }

    /// What a creature sorts by on the screen: its Perception, or a hazard's Stealth. 0 without a stat block.
    func rank(of combatant: Combatant) -> Int {
        guard let creature = stripCreature(for: combatant) else { return 0 }
        let presenter = StatBlockPresenter(creature: creature, template: combatant.template,
                                           conditions: combatant.conditions)
        return creature.kind == .hazard ? presenter.initiative.value : presenter.perception.value
    }
}
