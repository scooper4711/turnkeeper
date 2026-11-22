import CreatureArt
import Foundation

/// The creature art from the user's own Paizo PDFs (R2.3), kept by Tabletop Kit's art store.
extension CreatureArtStore {
    /// The app's own art library, used until it has moved into the shared one (shared libraries R6.5). It is apart
    /// from the `Art` folder, whose unused files are swept at launch.
    static func ownFolder() -> URL {
        URL.applicationSupportDirectory.appendingPathComponent("Turnkeeper/Creature Art")
    }

    static func own() throws -> CreatureArtStore {
        try CreatureArtStore(folder: ownFolder())
    }
}
