import Bestiary
import Foundation

/// A creature or complex hazard the GM made, by hand or from a stat block copied out of a PDF, or a custom pawn
/// made in Pawn Shop. It is kept in the shared creature library, belongs to no campaign, and works everywhere a
/// bestiary creature does, under the key `custom.<id>`.
public struct CustomCreature: LibraryRecord, Hashable {
    public var id = UUID()
    /// The campaign it was made in, so the browser can list it first there; nil for a custom pawn.
    public var campaignID: UUID?
    /// True for a custom pawn that has only a name, a size and art so far (shared libraries R4.6).
    public var isNameOnly: Bool?
    /// The scenario it was made for, if any, so the browser can list it first there.
    public var scenarioID: UUID?
    public var creature: Creature
    /// The organized-play subtier the stat block was printed for, such as "1-2", when known.
    public var subtier = ""
    public var modifiedAt = Date()
    public var deletedAt: Date?
    public var sharedVersion: Date?
    public var sharedVersions: [Date]?

    public static let keyPrefix = "custom."

    /// A new custom creature for a campaign, named and in the campaign's game, with everything else empty.
    public init(campaignID: UUID, game: Game, name: String) {
        self.campaignID = campaignID
        creature = Creature(key: Self.keyPrefix + id.uuidString, name: name, game: game)
        creature.source = Source(pack: "custom", title: "Custom", isRemastered: true)
    }

    /// A custom pawn from the shared library: its name and size, with no stat block, campaign or game yet.
    public init(nameOnlyID id: UUID, name: String, size: String) {
        self.id = id
        isNameOnly = true
        creature = Creature(key: Self.keyPrefix + id.uuidString, name: name, game: .pathfinder)
        creature.source = Source(pack: "custom", title: "Custom", isRemastered: true)
        creature.traits.size = size
    }

    public var key: String { creature.key }

    public var hasStatBlock: Bool { isNameOnly != true }

    /// The creature with the stat block just written for it, which settles its campaign and game (R4.10).
    public func givingStatBlock(_ statBlock: Creature, campaignID: UUID?, game: Game) -> CustomCreature {
        var custom = self
        custom.creature = statBlock
        guard !hasStatBlock else { return custom }
        custom.isNameOnly = nil
        custom.campaignID = campaignID
        custom.creature.game = game
        return custom
    }

    public static func isCustomKey(_ key: String) -> Bool { key.hasPrefix(keyPrefix) }
}
