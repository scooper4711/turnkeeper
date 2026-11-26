#if os(macOS)
import Bestiary
import Foundation
import TablesideShared
import TurnkeeperKit

/// Sending Pawn Shop the pawns that encounters need (R3.9).
extension AppModel {
    /// Asks the system whether a Pawn Shop that takes the request is installed. Done at launch and whenever the
    /// app comes forward, not as rows draw.
    func lookForPawnShop() {
        canOpenInPawnShop = WorkspaceLauncher().canOpen(PawnSheetRequest.probeURL)
    }

    /// Brings Pawn Shop forward with a new sheet named `title`, holding the pawns the tally's fights need.
    func openInPawnShop(_ tally: PawnTally, titled title: String) {
        let request = tally.request(titled: title) { creaturePawn(for: $0) }
        WorkspaceLauncher().openInForeground(request.url)
    }

    /// A custom creature's pawn is its own, under its ID. A bestiary creature's is the art the library matches to
    /// its name, even when it shows pasted art here: Pawn Shop has no pawn of that. Nil for a creature that is gone.
    private func creaturePawn(for key: String) -> CreaturePawn? {
        if CustomCreature.isCustomKey(key) {
            return library.customCreature(key: key).map { CreaturePawn(name: $0.creature.name, pawnID: $0.id) }
        }
        return bestiary.entry(key).map { CreaturePawn(name: $0.name, pawnID: matchedArt(for: $0).portrait) }
    }
}
#endif
