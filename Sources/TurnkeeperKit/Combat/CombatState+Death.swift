import Foundation

/// Dead: a strip that stays on the ladder, grayed out, and is passed over when the turn moves on.
public extension CombatState {
    /// Marks a combatant dead. It keeps its place, stops delaying, and has no more turns or reminders. One
    /// that dies on its own turn stays current until the GM passes the turn.
    mutating func markDead(_ id: UUID) {
        guard var combatant = self[id] else { return }
        combatant.isDead = true
        combatant.isDelaying = false
        combatant.delayedMidTurn = false
        self[id] = combatant
    }

    /// Undoes Dead, for a misclick or a resurrection. The strip acts again when the order reaches it.
    mutating func revive(_ id: UUID) {
        self[id]?.isDead = false
    }

    /// Follows HP after a change: a combatant with tracked HP that the change brought to 0 HP dies, unless the
    /// GM knocked it out instead, and a dead one healed above 0 HP lives again. Only a change in damage counts,
    /// so a strip the GM revived or knocked out at 0 HP stays as the GM left it. `maxHitPoints` is a
    /// combatant's maximum HP, 0 when unknown.
    mutating func settleDeaths(since previous: CombatState, maxHitPoints: (Combatant) -> Int) {
        for combatant in combatants where combatant.tracksHitPoints {
            let maximum = maxHitPoints(combatant)
            guard maximum > 0, let before = previous[combatant.id]?.damageTaken else { continue }
            let isDown = combatant.damageTaken >= maximum
            if isDown, before < maximum, !combatant.isDying {
                markDead(combatant.id)
            } else if combatant.isDead, !isDown, combatant.damageTaken < before {
                revive(combatant.id)
            }
        }
    }
}
