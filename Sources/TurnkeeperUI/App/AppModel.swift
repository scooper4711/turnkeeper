import CharacterImport
import Bestiary
import TurnkeeperKit
import CreatureArt
import Foundation
import Observation
import TablesideSync
import TablesideShared

/// What the planner's detail column shows.
enum PlannerSelection: Hashable {
    case scenario(UUID)
    case encounter(UUID)
    case party(UUID)
    case handout(UUID)
}

/// The app's state: the library, the bestiary, and what is selected or running. Every library change is
/// saved shortly after it happens.
@Observable
@MainActor
final class AppModel {
    var library: Library {
        didSet { scheduleSave() }
    }
    let bestiary: BestiaryStore
    var selectedCampaignID: UUID? {
        // Only the saved library's choice is kept; demos and tests leave it alone.
        didSet { if file != nil { LastCampaign.id = selectedCampaignID } }
    }
    var selection: PlannerSelection?
    /// The fight on screen; the planner shows when nil.
    var activeSessionID: UUID? {
        // Leaving a fight applies what other devices changed in it meanwhile.
        didSet { if activeSessionID != oldValue { campaignSync?.releaseHeldRecords() } }
    }
    var errorMessage: String?
    /// A Demiplane sheet the error says to open, offered as a button beside it.
    var errorSheetURL: URL?
    /// A passing message, such as the result of an import.
    var statusMessage: String?
    /// The library sheet open over the window, from the sidebar's More menu or the menu bar.
    var librarySheet: LibrarySheet?
    /// True while the picker for a `.turnkeeper` file to import is open.
    var isImportingLibrary = false
    /// A campaign's file waiting for the user to choose where to save it.
    var campaignExport: LibraryDocument?
    /// A planning edit that would reset a fight in progress, waiting for the GM to confirm.
    var pendingPlanChange: PendingPlanChange?
    /// What the last paste or drop of stat blocks added, shown until dismissed.
    var statBlockImport: StatBlockImport?
    /// What a Demiplane import is doing, while it runs.
    var demiplaneProgress: String?
    /// The party member whose sheet is being refreshed, for the progress on its row.
    var refreshingMemberID: UUID?
    /// True when a Pawn Shop that takes pawn sheet requests is installed (R3.9); only the Mac looks.
    var canOpenInPawnShop = false

    /// Where handouts' images are kept, and pasted artwork until the app moves into the shared library.
    @ObservationIgnored let artStore: ArtStore?
    /// The shared creature library; nil when the app keeps custom creatures in its own library (R6.5).
    @ObservationIgnored let sharedCreatures: SharedCreatureStore?
    /// Tells the model when another app changes the shared library.
    @ObservationIgnored var sharedChangeObserver: LibraryChangeObserver?
    /// The creature art from the user's PDFs; nil when there's nowhere to keep it.
    @ObservationIgnored let creatureArt: CreatureArtStore?
    /// What the art library holds, and the creatures' art matched from it.
    var artCatalog = ArtCatalog()
    var artMatcher = LibraryArtMatcher()
    /// The missing PDFs a creature needs for its art, which are the ones worth a warning.
    var artSourcesNeeded: [ArtSourceSummary] = []
    /// What reading PDFs of art is doing, while it runs.
    var artProgress: String?
    @ObservationIgnored let file: LibraryFile?
    /// The iconic pregens a GM can add as Table Buddies, read when first needed.
    @ObservationIgnored lazy var pregens: PregenCatalog = BestiaryStore.locateGeneratedDirectory()
        .map { PregenCatalog(folder: $0.appendingPathComponent("Pregens")) } ?? PregenCatalog()
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    /// Syncing through iCloud, once started; nil on a build or device without it.
    @ObservationIgnored var librarySync: LibrarySync?
    @ObservationIgnored var campaignSync: CampaignSync?
    @ObservationIgnored var cloudAccountObserver: (any NSObjectProtocol)?
    @ObservationIgnored var isConnectingCloudSync = false
    /// When the pictures of each piece of art were last asked of iCloud.
    @ObservationIgnored var cloudPictureAttempts: [UUID: Date] = [:]
    /// True while the app is in the background, when the shared database must be closed after each use.
    @ObservationIgnored var isInBackground = false
    /// Whether iCloud has changes from a newer version of the app, which wait until this one is updated.
    var needsUpdateToSync = false
    /// Whether the library is syncing, for the menus.
    var cloudSyncStatus = SyncStatus.withoutSync(containerIdentifier: LibrarySync.bundleContainer)

    init(library: Library = Library(), bestiary: BestiaryStore = BestiaryStore(), file: LibraryFile? = nil,
         artStore: ArtStore? = nil, creatureArt: CreatureArtStore? = nil,
         sharedCreatures: SharedCreatureStore? = nil) {
        self.library = library
        self.bestiary = bestiary
        self.file = file
        self.artStore = artStore
        self.creatureArt = creatureArt
        self.sharedCreatures = sharedCreatures
        selectedCampaignID = library.activeCampaign(preferring: file == nil ? nil : LastCampaign.id)?.id
    }

    /// The app's model, with the saved library and the bundled bestiary.
    static func live() -> AppModel {
        let bestiary = BestiaryStore.locateGeneratedDirectory().flatMap { try? BestiaryStore(generatedDirectory: $0) }
        // The glossary is large; reading it now keeps the first tap on a linked word quick.
        if let bestiary { Task.detached(priority: .utility) { _ = bestiary.glossaryEntry("") } }
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--demo") {
            let mode = arguments.indices.contains(index + 1) ? arguments[index + 1] : "planner"
            return DemoLibrary.model(mode: mode, bestiary: bestiary ?? BestiaryStore())
        }
        do {
            let file = try LibraryFile.standard()
            let library = try file.load()
            let artStore = try? ArtStore.standard()
            let opening = SharedLibraryOpening.open(moving: library, pastedArt: artStore)
            // Once moved, the art folder holds only handouts; before that it still holds the pasted art too.
            artStore?.sweep(keeping: opening.creatures == nil ? library.liveImageFileNames
                                                              : library.liveHandoutFileNames)
            let model = AppModel(library: library, bestiary: bestiary ?? BestiaryStore(), file: file,
                                 artStore: artStore, creatureArt: opening.art, sharedCreatures: opening.creatures)
            model.errorMessage = opening.failure
            model.startFollowingSharedLibrary()
            model.startCloudSync()
            Task { await model.refreshCreatureArt(addingNew: true) }
            return model
        } catch {
            let model = AppModel(bestiary: bestiary ?? BestiaryStore())
            model.errorMessage = error.localizedDescription
            return model
        }
    }

    var selectedCampaign: Campaign? {
        library.campaigns.first { $0.id == selectedCampaignID && !$0.isDeleted }
    }

    var game: Game { selectedCampaign?.game ?? .pathfinder }

    var activeSession: CombatSession? {
        library.sessions.first { $0.id == activeSessionID }
    }

    /// A creature's summary, from a linked PC, the campaign's custom creatures or the bestiary, with any
    /// pasted art (a PC's portrait is its Demiplane avatar, stored as pasted art), else its art from the user's
    /// PDFs.
    func entry(_ key: String) -> BestiaryIndexEntry? {
        let found = CustomCreature.isCustomKey(key) || PlayerCharacter.isKey(key)
            ? creature(key).map(BestiaryIndexEntry.init)
            : bestiary.entry(key)
        guard var entry = found else { return nil }
        if let art = library.customArt(for: key) {
            entry.art = entry.art.replacing(with: art)
            return entry
        }
        return entry.art.hasArt ? entry : withLibraryArt(entry)
    }

    /// The file behind an art path: pasted art from its store, anything else from the bundled bestiary. Art from
    /// the user's PDFs has no file; `artPicture(for:maxPixels:)` draws it.
    func artURL(for path: String) -> URL? {
        guard path.hasPrefix(CustomArt.pathPrefix) else { return bestiary.url(for: path) }
        let fileName = String(path.dropFirst(CustomArt.pathPrefix.count))
        if let pastedArtStore, pastedArtStore.contains(fileName) { return pastedArtStore.url(for: fileName) }
        return artStore?.url(for: fileName)
    }

    /// A creature's full stat block, from a linked PC's sheet, the campaign's custom creatures or the bestiary.
    func creature(_ key: String) -> Creature? {
        if CustomCreature.isCustomKey(key) { return library.customCreature(key: key)?.creature }
        if let memberID = PlayerCharacter.memberID(fromKey: key) {
            return partyMember(memberID).flatMap(PlayerCharacter.creature(for:))
        }
        return bestiary.creature(key)
    }

    /// Saves now, for when the app goes to the background.
    func saveNow() {
        saveTask?.cancel()
        write()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            self?.write()
        }
    }

    private func write() {
        guard let file else { return }
        do {
            try saveLibrary(to: file)
            tellCloudSyncOfChanges()
        } catch {
            errorMessage = "Saving the library failed: \(error.localizedDescription)"
        }
    }
}
