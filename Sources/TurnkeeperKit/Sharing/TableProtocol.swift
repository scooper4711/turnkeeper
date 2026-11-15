import Bestiary
import Foundation

/// The Bonjour service type of a device sharing its player screen.
public let tableServiceType = "_turnkeeper-table._tcp"

/// What a card back needs to be drawn on another device: never a stat block or a number.
public struct TableCard: Codable, Sendable, Hashable {
    public var name: String
    public var game: Game
    /// The creature's traits, which pick the landscape behind it.
    public var traits: [String]
    /// What to ask the sharing device for to get the art; empty when there is none.
    public var artID: String

    public init(name: String, game: Game, traits: [String], artID: String) {
        self.name = name
        self.game = game
        self.traits = traits
        self.artID = artID
    }
}

/// One strip of the initiative order as it is sent to a following device: a `PlayerScreenLine` and its card back.
public struct TableLine: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var name: String
    public var magnet: Magnet
    public var isActive: Bool
    public var isDelaying: Bool
    /// Nil from a host whose version has no Dead status.
    public var isDead: Bool?
    /// A `HealthEstimate`, by its name; nil for PCs and allies.
    public var health: String?
    public var card: TableCard?

    public init(_ line: PlayerScreenLine, card: TableCard?) {
        id = line.id
        name = line.name
        magnet = line.magnet
        isActive = line.isActive
        isDelaying = line.isDelaying
        isDead = line.isDead
        health = line.health?.rawValue
        self.card = card
    }

    /// The strip as the player screen draws it.
    public var playerLine: PlayerScreenLine {
        var line = PlayerScreenLine(id: id, name: name, magnet: magnet, isActive: isActive, isDelaying: isDelaying,
                                    health: health.flatMap(HealthEstimate.init(rawValue:)))
        line.isDead = isDead ?? false
        return line
    }
}

/// What the players are shown at one moment, sent whole to every following device.
public struct TableSnapshot: Codable, Sendable, Equatable {
    public enum Content: Codable, Sendable, Equatable {
        /// No fight is open and no handout is on show.
        case waiting
        case fight([TableLine])
        case handout(name: String, artID: String)
    }

    /// Rises with every snapshot a sharing device sends, so a follower can drop one that arrives late.
    public var sequence: Int
    public var content: Content

    public init(sequence: Int = 0, content: Content) {
        self.sequence = sequence
        self.content = content
    }
}

public extension TableSnapshot.Content {
    /// The fight as it is sent: each strip with the card back `card` gives for its creature key.
    static func fight(_ fight: PlayerScreenFight, card: (String) -> TableCard?) -> Self {
        .fight(fight.lines.map { line in
            TableLine(line, card: line.creatureKey.isEmpty ? nil : card(line.creatureKey))
        })
    }

    /// The art a follower may ask for: the card backs' and the handout's.
    var artIDs: Set<String> {
        switch self {
        case .waiting: return []
        case let .fight(lines): return Set(lines.compactMap(\.card?.artID)).subtracting([""])
        case let .handout(_, artID): return artID.isEmpty ? [] : [artID]
        }
    }

    /// The strip whose turn it is.
    var activeLine: TableLine? {
        guard case let .fight(lines) = self else { return nil }
        return lines.first(where: \.isActive)
    }
}

/// Messages between a device sharing its player screen and the devices following it.
///
/// A follower sends `join` with the code shown on the sharing device, which answers `welcome` and the current
/// snapshot, or `refused`. From then on the sharing device sends a snapshot whenever the player screen changes,
/// and a follower asks for the art it doesn't have yet with `needArt`.
public enum TableMessage: Codable, Sendable, Equatable {
    case join(code: String, name: String)
    case welcome
    case refused(reason: String)
    case snapshot(TableSnapshot)
    case needArt(id: String)
    /// The art's image file; empty when the sharing device has none for that ID.
    case art(id: String, image: Data)
}

public enum TableError: Error, LocalizedError, Equatable {
    case refused(String)
    case connectionLost(String)

    public var errorDescription: String? {
        switch self {
        case let .refused(reason): return "Joining failed: \(reason)"
        case let .connectionLost(reason): return "Following the table failed: the connection broke (\(reason))."
        }
    }
}

/// How long a follower waits before trying to reach the sharing device again.
public enum ReconnectDelay {
    /// Half a second after the first failure, doubling to at most five seconds, so a phone coming back from
    /// another app is following again at once and one left open doesn't hammer the network.
    public static func seconds(afterFailures failures: Int) -> Double {
        guard failures > 1 else { return 0.5 }
        return min(0.5 * pow(2, Double(min(failures, 10) - 1)), 5)
    }
}
