import CreatureArt
import Foundation
import SharedLibraries
import TablesideShared
import TurnkeeperKit

/// What opening the shared library at launch gave the app.
struct SharedLibraryOpening {
    var creatures: SharedCreatureStore?
    var art: CreatureArtStore?
    /// Why the app carries on with its own library, to tell the user (shared libraries R6.5).
    var failure: String?

    /// Opens the shared library and moves the app's own into it, once. On failure the app keeps its own library,
    /// and the next launch tries again.
    @MainActor
    static func open(moving library: Library, pastedArt: ArtStore?) -> SharedLibraryOpening {
        // A build outside the App Group (ad hoc) shares this container with the signed app, so moving here would
        // strand the user's creatures in a folder the signed app never reads. It keeps its own library (R1.2).
        guard let group = ToolkitGroup.containerURL() else {
            return SharedLibraryOpening(art: try? CreatureArtStore.own())
        }
        let root = URL.applicationSupportDirectory.appendingPathComponent("Turnkeeper", isDirectory: true)
        let folder = group.appendingPathComponent(SharedLibrary.groupFolderName, isDirectory: true)
        do {
            let shared = try SharedLibrary(folder: folder, app: .turnkeeper)
            let creatures = try SharedCreatureStore(
                shared: shared, positionFile: root.appendingPathComponent("shared-library-position.json"))
            try creatures.moveIn(library, artFolder: CreatureArtStore.ownFolder(),
                                 pastedArtFolder: (pastedArt?.directory ?? root.appendingPathComponent("Art")))
            let art = try CreatureArtStore(sharedLibraryIn: folder, app: .turnkeeper)
            return SharedLibraryOpening(creatures: creatures, art: art)
        } catch {
            return SharedLibraryOpening(art: try? CreatureArtStore.own(),
                                        failure: "Moving to the shared library failed, so Turnkeeper is using its "
                                            + "own for now and will try again next launch: "
                                            + error.localizedDescription)
        }
    }
}

extension AppModel {
    /// Where pasted art goes: the shared library's folder, or the app's own until it has moved in.
    var pastedArtStore: ArtStore? { sharedCreatures?.artStore ?? artStore }

    /// Reads the shared library now and whenever any app changes it (R5.2).
    func startFollowingSharedLibrary() {
        guard sharedCreatures != nil else { return }
        followSharedLibrary()
        sharedChangeObserver = SharedLibraryChange.observe { [weak self] in self?.followSharedLibrary() }
    }

    /// Writes the library: creatures and art to the shared library, the rest to `library.json`. If the shared
    /// library can't take them, `library.json` keeps them all, so nothing is lost.
    func saveLibrary(to file: LibraryFile) throws {
        guard let sharedCreatures else { return try file.save(library) }
        do {
            try sharedCreatures.push(library)
            try pullSharedChanges(from: sharedCreatures)
        } catch {
            try file.save(library)
            throw error
        }
        try file.save(library.keepingOnlyLocalRecords())
        try sharedCreatures.savePosition()
    }

    /// Saves, and lets go of the shared database, which iOS would otherwise end the app for holding (R5.4).
    func saveAndCloseSharedLibrary() {
        saveNow()
        sharedCreatures?.shared.close()
        if let creatureArt { Task { await creatureArt.close() } }
    }

    private func followSharedLibrary() {
        guard let sharedCreatures else { return }
        do {
            try sharedCreatures.push(library)
            try pullSharedChanges(from: sharedCreatures)
        } catch {
            errorMessage = "Reading the shared library failed: \(error.localizedDescription)"
        }
    }

    private func pullSharedChanges(from store: SharedCreatureStore) throws {
        var pulled = library
        let changes = try store.pull(into: &pulled)
        if pulled != library { library = pulled }
        if changes.changedTables.contains(.art) || changes.deletions[.art] != nil {
            Task { await refreshCreatureArt() }
        }
    }
}
