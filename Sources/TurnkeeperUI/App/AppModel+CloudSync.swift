import CloudKit
import Foundation
import TablesideSync
import TurnkeeperKit

/// Syncing the library between the user's devices through iCloud: custom creatures and art through the shared
/// library's zones, everything else through Turnkeeper's own.
extension AppModel: CampaignSyncHost {
    var handoutImages: ArtStore? { artStore }

    /// A pause that can't be read counts as one.
    var isCloudSyncPaused: Bool {
        guard let shared = sharedCreatures?.shared else { return true }
        return (try? shared.isSyncPaused) != false
    }

    func pauseCloudSync() {
        try? sharedCreatures?.shared.setSyncPaused(true)
    }

    func finishCloudSyncWork() {
        if isInBackground { sharedCreatures?.shared.close() }
    }

    /// Starts syncing where the build names the container and the device has an iCloud account, and tries again
    /// when the account changes. Only after the move to the shared library, and never for the demo or tests.
    func startCloudSync() {
        guard file != nil, sharedCreatures != nil, !LibrarySync.bundleContainer.isEmpty else { return }
        if cloudAccountObserver == nil {
            cloudAccountObserver = NotificationCenter.default.addObserver(
                forName: .CKAccountChanged, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.connectCloudSync() }
            }
        }
        connectCloudSync()
    }

    /// Lets syncing use the shared library again after the background, and sends what changed meanwhile.
    func resumeCloudSync() {
        isInBackground = false
        guard let librarySync else { return connectCloudSync() }
        Task {
            await librarySync.open()
            await librarySync.libraryChanged()
        }
    }

    /// In the background this waits for the return to the foreground, as the shared library must stay closed.
    func tellCloudSyncOfChanges() {
        guard !isInBackground else { return }
        campaignSync?.libraryChanged()
        if let librarySync { Task { await librarySync.libraryChanged() } }
    }

    /// Downloads the pictures of art this device lacks; true when any arrived. A picture no device has uploaded
    /// yet isn't asked for again for a minute, as a screen of art would otherwise ask at every draw.
    func fetchCloudPictures(ofArt id: UUID) async -> Bool {
        guard let librarySync, let shared = sharedCreatures?.shared,
              Date().timeIntervalSince(cloudPictureAttempts[id] ?? .distantPast) > Self.cloudPictureRetry,
              let entry = try? shared.artEntry(id: id) else { return false }
        let names = shared.missingPictures(of: entry)
        guard !names.isEmpty else { return false }
        cloudPictureAttempts[id] = Date()
        return await !librarySync.fetchPictures(named: names).isEmpty
    }

    private static var cloudPictureRetry: TimeInterval { 60 }

    /// One line for the menus.
    var cloudSyncStatusText: String {
        switch cloudSyncStatus {
        case .unsupported: "iCloud: Not in This Build"
        case .unavailable: "iCloud: Signed Out"
        case .syncing: "iCloud: Syncing…"
        case .upToDate: "iCloud: Up to Date"
        case .paused: "iCloud: Paused"
        case .storageFull: "iCloud: Storage Full"
        case .failed: "iCloud: Sync Failed"
        }
    }

    private func connectCloudSync() {
        guard librarySync == nil, !isConnectingCloudSync, !LibrarySync.bundleContainer.isEmpty, let file,
              let shared = sharedCreatures?.shared else { return }
        // A launch, a return to the foreground and an account change can all ask at once; one engine must result.
        isConnectingCloudSync = true
        let folder = file.url.deletingLastPathComponent()
        let handler = campaignSync ?? CampaignSync(host: self, folder: folder)
        campaignSync = handler
        handler.retireOrphans()
        Task {
            let started = await LibrarySync.start(app: .turnkeeper, fallback: shared.folder, handlers: [handler])
            isConnectingCloudSync = false
            guard let sync = started else { return }
            librarySync = sync
            for await status in await sync.statusUpdates() { cloudSyncStatus = status }
        }
    }
}
