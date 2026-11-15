import Foundation

/// How the board is laid out in the space it has: the initiative ladder beside the battle card, or, on an iPhone
/// and in a narrow or short window, the ladder alone with the card in a sheet.
public enum BoardArrangement: Sendable, Equatable {
    case sideBySide
    case ladderOnly

    /// Below this width a strip and a battle card no longer fit beside each other.
    public static let minimumSideBySideWidth = 760.0
    /// Below this height (an iPhone on its side) the card and its notes have no room under the top bar.
    public static let minimumSideBySideHeight = 480.0

    /// The arrangement for a board of `width` by `height` points, top bar excluded.
    public init(width: Double, height: Double) {
        let hasRoom = width > Self.minimumSideBySideWidth && height >= Self.minimumSideBySideHeight
        self = hasRoom ? .sideBySide : .ladderOnly
    }

    /// With the ladder alone, whether the turn buttons get a bar of their own below it, in reach of a thumb. On a
    /// short board (an iPhone on its side) they join the top bar, leaving the height to the ladder.
    public static func hasTurnBar(height: Double) -> Bool {
        height >= minimumSideBySideHeight
    }

    /// The ladder's width: its share beside the card, or all of it.
    public func ladderWidth(in width: Double) -> Double {
        self == .sideBySide ? width * 0.48 : width
    }
}
