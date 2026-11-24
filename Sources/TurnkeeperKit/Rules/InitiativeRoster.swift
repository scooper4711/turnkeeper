import Foundation

/// The rows of the voice initiative screen: the PCs in the table's seating order, then, with Show all, the
/// creatures, sorted for doing the math. Only ladder combatants; the bench stays out.
///
/// Ties keep the order the fight was set up in, not the ladder's: in setup the ladder re-sorts with each number,
/// which would make the rows jump while the GM enters them.
public struct InitiativeRoster: Sendable {
    /// The PCs: seated members in seating order, then the rest in setup order.
    public let pcs: [Combatant]
    /// With Show all, the creatures and hazards by rank, highest first, the same kind and template together.
    public let creatures: [Combatant]

    /// - Parameters:
    ///   - seating: party member IDs in seating order.
    ///   - rank: what a creature sorts by, highest first: its Perception, or a hazard's Stealth.
    public init(state: CombatState, seating: [UUID], showsAll: Bool, rank: (Combatant) -> Int) {
        let onLadder = Set(state.order)
        let ladder = state.combatants.filter { onLadder.contains($0.id) }
        pcs = Self.seated(ladder.filter { $0.kind == .playerCharacter }, seating: seating)
        creatures = showsAll ? Self.ranked(ladder.filter { $0.kind != .playerCharacter }, rank: rank) : []
    }

    /// Every row, top to bottom.
    public var rows: [Combatant] { pcs + creatures }

    /// The first row still without an initiative.
    public var firstOpen: UUID? { rows.first { $0.initiative == nil }?.id }

    /// The next row without an initiative after `id`, going down and wrapping around; nil when everyone has
    /// one. When `id` isn't a row, the first row without one.
    public func nextOpen(after id: UUID) -> UUID? {
        guard let index = rows.firstIndex(where: { $0.id == id }) else { return firstOpen }
        let wrapped = rows[(index + 1)...] + rows[..<index]
        return wrapped.first { $0.initiative == nil }?.id
    }

    /// Which of several rows a spoken name means: the first, top to bottom, still without an initiative, or
    /// the first when they all have one. Nil when none of them is a row.
    public func pick(_ matches: [UUID]) -> UUID? {
        let wanted = Set(matches)
        let candidates = rows.filter { wanted.contains($0.id) }
        return (candidates.first { $0.initiative == nil } ?? candidates.first)?.id
    }

    /// The seating order after the GM drags PC rows: `source` rows moved to before row `destination`, as
    /// SwiftUI's `onMove` reports it. Members seated but not in this fight, such as players away, keep their
    /// places; PCs without a member are left out.
    public func seating(afterMoving source: IndexSet, to destination: Int, in seating: [UUID]) -> [UUID] {
        var order = pcs.indices.filter { !source.contains($0) }
        order.insert(contentsOf: source.sorted(), at: order.filter { $0 < destination }.count)
        let reordered = order.compactMap { pcs[$0].linkedMemberID }
        return Self.replacingSeats(of: reordered, in: seating)
    }

    // MARK: Building the rows

    private static func seated(_ pcs: [Combatant], seating: [UUID]) -> [Combatant] {
        let seat = Dictionary(seating.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        // Unseated PCs sort after every seat, in setup order.
        let keyed = pcs.enumerated().map { index, pc in
            (pc, pc.linkedMemberID.flatMap { seat[$0] } ?? Int.max, index)
        }
        return keyed.sorted { ($0.1, $0.2) < ($1.1, $1.2) }.map(\.0)
    }

    private static func ranked(_ creatures: [Combatant], rank: (Combatant) -> Int) -> [Combatant] {
        let keyed = creatures.enumerated().map { index, creature in (creature, rank(creature), index) }
        return keyed.sorted { first, second in
            if first.1 != second.1 { return first.1 > second.1 }
            if first.0.creatureKey != second.0.creatureKey { return first.0.creatureKey < second.0.creatureKey }
            if first.0.template != second.0.template { return first.0.template.rawValue < second.0.template.rawValue }
            return first.2 < second.2
        }.map(\.0)
    }

    /// `seating` with the members in `reordered` put in that order in the seats they held; members not seated
    /// before come after.
    private static func replacingSeats(of reordered: [UUID], in seating: [UUID]) -> [UUID] {
        let moving = Set(reordered)
        var queue = reordered[...]
        var result = seating.compactMap { id in moving.contains(id) ? queue.popFirst() : id }
        result += queue
        return result
    }
}

public extension Combatant {
    /// The party member a PC is, from `memberID`, or from its `pc.` key in sessions saved before it was kept.
    var linkedMemberID: UUID? {
        memberID ?? PlayerCharacter.memberID(fromKey: creatureKey)
    }
}
