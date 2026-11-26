import Foundation
import TablesideShared

/// A creature's pawn, as Pawn Shop is told of it: the creature's name and, when the creature has one, the pawn.
public struct CreaturePawn: Equatable, Sendable {
    public var name: String
    /// The art's ID in the shared library, or a custom creature's own ID; nil for a creature without a pawn.
    public var pawnID: UUID?

    public init(name: String, pawnID: UUID? = nil) {
        self.name = name
        self.pawnID = pawnID
    }
}

/// How many pawns a set of fights needs (R3.9). A fight is one encounter at one difficulty: within it, slots that
/// use the same pawn add up, and across fights the largest number wins, since only one fight is on the table at a
/// time.
public struct PawnTally: Sendable {
    private let fights: [EncounterVariant]

    /// The fights of `encounters` at each of the difficulties in `labels`.
    public init(encounters: [Encounter], labels: [String]) {
        fights = encounters.flatMap { encounter in labels.map(encounter.variant) }
    }

    /// True when any fight has a creature planned.
    public var hasCreatures: Bool {
        fights.contains { fight in fight.slots.contains { $0.count >= 1 } }
    }

    /// The request for a sheet holding the pawns, in the order the fights plan them. `pawn` gives a creature's
    /// pawn from its key, or nil for a creature that is gone, which is left out.
    public func request(titled title: String, pawn: (String) -> CreaturePawn?) -> PawnSheetRequest {
        var lines: [PawnSheetRequest.Line] = []
        var indexes: [String: Int] = [:]
        for fight in fights {
            for need in Self.needs(of: fight, pawn: pawn) {
                if let index = indexes[need.key] {
                    lines[index].count = max(lines[index].count, need.line.count)
                } else {
                    indexes[need.key] = lines.count
                    lines.append(need.line)
                }
            }
        }
        return PawnSheetRequest(title: title, lines: lines)
    }

    /// What one fight needs, with slots of the same pawn added up.
    private static func needs(of fight: EncounterVariant, pawn: (String) -> CreaturePawn?) -> [Need] {
        var needs: [Need] = []
        for slot in fight.slots where slot.count >= 1 {
            guard let found = pawn(slot.creatureKey) else { continue }
            let key = found.pawnID?.uuidString ?? slot.creatureKey
            if let index = needs.firstIndex(where: { $0.key == key }) {
                needs[index].line.count += slot.count
            } else {
                needs.append(Need(key: key, line: .init(name: found.name, count: slot.count, pawnID: found.pawnID)))
            }
        }
        return needs
    }

    /// A line of the request with what tells its pawn from the others: the pawn's ID, or the creature's key for
    /// a creature without a pawn.
    private struct Need {
        var key: String
        var line: PawnSheetRequest.Line
    }
}
