import CloudKit
import Foundation
import TablesideSync

/// What syncing needs from the app.
@MainActor
public protocol CampaignSyncHost: AnyObject {
    var library: Library { get set }
    /// The fight on screen, which a change from another device must not replace mid-turn.
    var activeSessionID: UUID? { get }
    /// Where handout images are kept.
    var handoutImages: ArtStore? { get }
    /// Whether the user deleted the app's iCloud data; the shared library keeps this for all zones.
    var isCloudSyncPaused: Bool { get }
    func pauseCloudSync()
    /// Syncing is done for now: on the iPad in the background, the shared library must be closed again.
    func finishCloudSyncWork()
}

/// Syncs campaigns, parties, scenarios, encounters, fights, handouts and creature notes through the zone `Turnkeeper`
/// of the suite's private CloudKit database: one of the owners of zones on the toolkit's engine, beside the shared
/// library's own, which syncs custom creatures and art.
@MainActor
public final class CampaignSync: SyncZoneHandler {
    private weak var host: (any CampaignSyncHost)?
    private let coder: CampaignRecordCoder
    private let stateFile: URL
    private var state: CampaignSyncState
    /// The digests of records handed to the engine, until the server takes them.
    private var outgoing: [String: String] = [:]
    /// Digests by record name and stamp, so a change doesn't re-encode the whole library.
    private var digests: [String: (modifiedAt: Date, digest: String)] = [:]
    private var isStorageFull = false
    /// Why the last save of the sync state or merge failed; nil when all is well.
    public private(set) var problem: String?

    /// - Parameter folder: Where the sync state and uploads in progress are kept, beside `library.json`.
    public init(host: any CampaignSyncHost, folder: URL) {
        self.host = host
        coder = CampaignRecordCoder(outgoingFolder: folder.appendingPathComponent("Sync/Outgoing", isDirectory: true))
        stateFile = folder.appendingPathComponent("campaign-sync-state.json")
        state = CampaignSyncState.load(from: stateFile)
        coder.removeOutgoingFiles()
        releaseHeldRecords()
    }

    /// Tells syncing the user changed something: a full iCloud is tried again.
    public func libraryChanged() {
        isStorageFull = false
    }

    /// Tells syncing a file import merged into the library: a merged party keeps its stamp with new content, so
    /// the digests known by stamp can't be trusted.
    public func libraryMerged() {
        digests = [:]
        isStorageFull = false
    }

    /// Applies what was held back and can be applied now, such as changes to a fight the GM has left.
    public func releaseHeldRecords() {
        let activeSession = host?.activeSessionID
        let ready = state.held.compactMap { name, held -> RemoteCampaignRecord? in
            guard let reference = CampaignRecordReference(recordName: name), held.format <= CampaignRecordCoder.format,
                  !(reference.kind == .session && reference.id == activeSession) else { return nil }
            return RemoteCampaignRecord(reference: reference, format: held.format, payload: held.payload,
                                        systemFields: held.systemFields)
        }
        guard !ready.isEmpty else { return }
        for record in ready { state.held[record.reference.recordName] = nil }
        apply(ready)
    }

    // MARK: SyncZoneHandler

    public func zones() -> [CKRecordZone.ID] {
        [CampaignRecordCoder.zone]
    }

    /// The records whose content differs from what the server holds; none while paused or iCloud is full.
    public func pendingChanges() -> [SyncChange] {
        defer { finish() }
        guard let host, !isStorageFull, !host.isCloudSyncPaused else { return [] }
        return host.library.campaignSyncRecords.compactMap { reference, record in
            let name = reference.recordName
            guard state.held[name] == nil, let digest = digest(of: record, named: name),
                  digest != state.entries[name]?.digest else { return nil }
            return .save(CampaignRecordCoder.recordID(of: reference))
        }
    }

    /// The record to save; nil when it is gone, already on the server, held, or syncing is paused.
    public func record(for recordID: CKRecord.ID) -> CKRecord? {
        defer { finish() }
        guard let host, !host.isCloudSyncPaused, let reference = CampaignRecordCoder.reference(of: recordID),
              state.held[reference.recordName] == nil,
              let record = host.library.campaignSyncRecord(reference),
              let digest = digest(of: record, named: reference.recordName),
              digest != state.entries[reference.recordName]?.digest,
              let cloudRecord = cloudRecord(for: record, reference: reference) else { return nil }
        outgoing[reference.recordName] = digest
        return cloudRecord
    }

    public func received(_ changes: FetchedChanges) {
        defer { finish() }
        isStorageFull = false
        for deletion in changes.deletions {
            guard let reference = CampaignRecordCoder.reference(of: deletion.recordID) else { continue }
            // Deletions travel as tombstones, so a record gone from the server was removed by hand: send it again.
            state.entries[reference.recordName] = nil
        }
        apply(changes.modifications.compactMap(CampaignRecordCoder.remote(from:)))
    }

    public func sent(saved: [CKRecord], deleted: [CKRecord.ID]) {
        for record in saved {
            guard let reference = CampaignRecordCoder.reference(of: record.recordID),
                  let digest = outgoing.removeValue(forKey: reference.recordName) else { continue }
            coder.removeOutgoingFile(of: reference)
            state.entries[reference.recordName] = CampaignSyncEntry(
                systemFields: CampaignRecordCoder.systemFields(of: record), digest: digest)
        }
        saveState()
    }

    /// Settles refused saves. A record the server holds in another version is merged in as a fetched one is. A
    /// zone the server lacks holds none of the records, so everything goes up with the zone. Anything not named
    /// here the engine retries.
    public func settle(_ failures: [FailedSave]) -> Bool {
        defer { finish() }
        var savesZone = false
        var conflicts: [RemoteCampaignRecord] = []
        for failure in failures {
            switch failure.error.code {
            case .serverRecordChanged:
                if let server = failure.error.serverRecord.flatMap(CampaignRecordCoder.remote(from:)) {
                    conflicts.append(server)
                }
            case .unknownItem:
                CampaignRecordCoder.reference(of: failure.record.recordID).map {
                    state.entries[$0.recordName] = nil
                }
            case .zoneNotFound: savesZone = true
            case .userDeletedZone: pause()
            case .quotaExceeded: isStorageFull = true
            default: break
            }
        }
        if savesZone { forgetServer() }
        if conflicts.isEmpty { saveState() } else { apply(conflicts) }
        return savesZone
    }

    /// Forgets the server when the account isn't the one the state describes. The library stays, and goes up to
    /// the new account, merged with what is there.
    public func accountChanged(to user: String?) {
        guard let user, state.account != user else { return }
        forgetServer()
        state.account = user
        saveState()
    }

    /// iCloud data the user deleted pauses syncing; a zone deleted any other way is uploaded again.
    public func zoneDeleted(_ zoneID: CKRecordZone.ID, reason: CKDatabase.DatabaseChange.Deletion.Reason) -> Bool {
        defer { finish() }
        guard zoneID == CampaignRecordCoder.zone else { return false }
        if reason == .purged {
            pause()
            return false
        }
        forgetServer()
        return true
    }

    // MARK: Helpers

    private func apply(_ records: [RemoteCampaignRecord]) {
        guard let host else { return }
        var library = host.library
        var summary = MergeSummary()
        for record in records {
            storeImage(of: record)
            let name = record.reference.recordName
            guard canApply(record) else {
                state.held[name] = held(record)
                continue
            }
            do {
                let incoming = SyncedPayload(payload: record.payload, kind: record.reference.kind,
                                             baseDigest: state.entries[name]?.digest)
                let digest = try LibraryMerger.mergeSynced(incoming, into: &library, summary: &summary)
                state.entries[name] = CampaignSyncEntry(systemFields: record.systemFields, digest: digest)
                state.held[name] = nil
                digests[name] = nil
            } catch {
                state.held[name] = held(record)
                problem = "Merging \(name) from iCloud failed: \(error.localizedDescription)"
            }
        }
        if library != host.library { host.library = library }
        saveState()
    }

    private func canApply(_ record: RemoteCampaignRecord) -> Bool {
        guard record.format <= CampaignRecordCoder.format else { return false }
        return !(record.reference.kind == .session && record.reference.id == host?.activeSessionID)
    }

    private func held(_ record: RemoteCampaignRecord) -> HeldCampaignRecord {
        HeldCampaignRecord(format: record.format, payload: record.payload, systemFields: record.systemFields)
    }

    /// Copies a handout's image out of CloudKit's cache before the record that points to it is merged.
    private func storeImage(of record: RemoteCampaignRecord) {
        guard let store = host?.handoutImages, let name = record.imageName, Self.isPlainFileName(name),
              !store.contains(name), let file = record.imageFile, let data = try? Data(contentsOf: file) else { return }
        do {
            try store.write(data, as: name)
        } catch {
            problem = error.localizedDescription
        }
    }

    /// A name from the server stays inside the image folder.
    static func isPlainFileName(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".." && !name.contains("/") && !name.contains("\\")
    }

    private func cloudRecord(for record: any LibraryRecord, reference: CampaignRecordReference) -> CKRecord? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let payload = try? encoder.encode(record) else { return nil }
        let imageName = (record as? Handout).flatMap { $0.hasImage ? $0.fileName : nil }
        let imageFile = imageName.flatMap { name in
            host?.handoutImages.flatMap { $0.contains(name) ? $0.url(for: name) : nil }
        }
        let outgoing = OutgoingCampaignRecord(reference: reference, payload: payload,
                                              systemFields: state.entries[reference.recordName]?.systemFields,
                                              imageName: imageName, imageFile: imageFile)
        return try? coder.record(for: outgoing)
    }

    private func digest(of record: any LibraryRecord, named name: String) -> String? {
        if let known = digests[name], known.modifiedAt == record.modifiedAt { return known.digest }
        guard let digest = try? record.contentDigest() else { return nil }
        digests[name] = (record.modifiedAt, digest)
        return digest
    }

    private func pause() {
        host?.pauseCloudSync()
        forgetServer()
    }

    private func forgetServer() {
        state.entries = [:]
        state.held = state.held.filter { $0.value.format > CampaignRecordCoder.format }
        outgoing = [:]
        isStorageFull = false
        saveState()
    }

    private func saveState() {
        do {
            try state.save(to: stateFile)
        } catch {
            problem = "Saving the iCloud sync state failed: \(error.localizedDescription)"
        }
    }

    private func finish() {
        host?.finishCloudSyncWork()
    }
}
