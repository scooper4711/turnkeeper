import CloudKit
import Foundation
import TablesideSync
import Testing
@testable import TurnkeeperKit

/// The app's side of syncing, without CloudKit's servers.
@MainActor
final class FakeSyncHost: CampaignSyncHost {
    var library = Library()
    var activeSessionID: UUID?
    var handoutImages: ArtStore?
    var isCloudSyncPaused = false
    func pauseCloudSync() { isCloudSyncPaused = true }
    func finishCloudSyncWork() {}
}

/// One device: a library, its syncing, and a folder of its own.
@MainActor
struct SyncDevice {
    let host = FakeSyncHost()
    let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("CampaignSyncTests-\(UUID().uuidString)", isDirectory: true)
    let sync: CampaignSync

    init() {
        sync = CampaignSync(host: host, folder: folder)
        host.handoutImages = ArtStore(directory: folder.appendingPathComponent("Art", isDirectory: true))
    }

    /// Sends everything pending and returns the records, as the server holds them.
    @discardableResult
    func upload() -> [CKRecord] {
        let records = sync.pendingChanges().compactMap { change -> CKRecord? in
            guard case let .save(id) = change else { return nil }
            return sync.record(for: id)
        }
        sync.sent(saved: records, deleted: [])
        return records
    }

    func download(_ records: [CKRecord]) {
        sync.received(FetchedChanges(modifications: records))
    }

    var pendingCount: Int { sync.pendingChanges().count }
}

extension SyncDevice {
    /// Two devices that both hold one encounter, in step.
    static func pair() -> (mac: SyncDevice, ipad: SyncDevice) {
        let mac = SyncDevice(), ipad = SyncDevice()
        mac.host.library.save(Encounter(scenarioID: UUID(), name: "A. Signal Jammer"))
        ipad.download(mac.upload())
        return (mac, ipad)
    }

    func editNotes(_ notes: String) {
        var encounter = host.library.encounters[0]
        encounter.notes = notes
        host.library.save(encounter)
    }

    var encounterNames: [String] { host.library.encounters.map(\.name).sorted() }

    /// The next record this device would send, handed over but not yet taken by the server.
    func nextAttempt() throws -> CKRecord {
        let change = try #require(sync.pendingChanges().first)
        guard case let .save(id) = change else { throw CocoaError(.featureUnsupported) }
        return try #require(sync.record(for: id))
    }
}
