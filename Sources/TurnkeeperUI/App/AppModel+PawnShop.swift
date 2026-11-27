import Bestiary
import Foundation
import SharedLibraries
import TablesideShared
import TurnkeeperKit

/// Handing Pawn Shop the pawns that encounters need (R3.9).
extension AppModel {
    /// What to ask Pawn Shop for: a sheet named `title`, holding the pawns the tally's fights need.
    func pawnSheetRequest(_ tally: PawnTally, titled title: String) -> PawnSheetRequest {
        tally.request(titled: title) { creaturePawn(for: $0) }
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

#if os(macOS)
/// On the Mac a link opens the sheet in Pawn Shop.
extension AppModel {
    /// Asks the system whether a Pawn Shop that takes the request is installed. Done at launch and whenever the
    /// app comes forward, not as rows draw.
    func lookForPawnShop() {
        canOpenInPawnShop = WorkspaceLauncher().canOpen(PawnSheetRequest.probeURL)
    }

    /// Brings Pawn Shop forward with a new sheet named `title`, holding the pawns the tally's fights need.
    func openInPawnShop(_ tally: PawnTally, titled title: String) {
        WorkspaceLauncher().openInForeground(pawnSheetRequest(tally, titled: title).url)
    }
}
#else
import ArtExtraction

/// On the iPad and iPhone the share sheet hands over a sheet file, since no link can open a document there.
extension AppModel {
    /// Writes the pawns the tally's fights need as a sheet file named after `title`, and shows the share sheet
    /// for it (R3.9.6). The file is written here, when the item is chosen, not as menus draw.
    func sharePawnSheet(_ tally: PawnTally, titled title: String) {
        do {
            let request = pawnSheetRequest(tally, titled: title)
            ShareSheet.present(try PawnSheetShareFile.write(request, readerVersion: PawnExtractor.version))
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
#endif
