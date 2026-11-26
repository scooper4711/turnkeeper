#if os(macOS)
import Bestiary
import Foundation
import SharedLibraries
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

    /// A creature's pawn is the art it shows here (R3.9.3): a custom creature's own and a bestiary creature's
    /// pasted art, both under the creature's pawn ID, else the art the library matches to its name. Nil for a
    /// creature that is gone.
    private func creaturePawn(for key: String) -> CreaturePawn? {
        if CustomCreature.isCustomKey(key) {
            return library.customCreature(key: key).map { CreaturePawn(name: $0.creature.name, pawnID: $0.id) }
        }
        return bestiary.entry(key).map { entry in
            let hasPastedArt = library.customArt(for: key) != nil
            return CreaturePawn(name: entry.name, pawnID: hasPastedArt ? SharedLibrary.pawnID(forSubject: key)
                                                                       : matchedArt(for: entry).portrait)
        }
    }
}
#endif
