import Foundation

/// What this device knows the server holds for one record.
struct CampaignSyncEntry: Codable, Equatable {
    /// The record's archived system fields, so the next save is a change to it and not a conflict.
    var systemFields: Data
    /// The digest of the version both sides last agreed on: the base of the next merge.
    var digest: String
}

/// A version from the server that can't be applied yet: the fight on screen, or a format this version can't read.
struct HeldCampaignRecord: Codable, Equatable {
    var format: Int64
    var payload: Data
    var systemFields: Data
}

/// Turnkeeper's side of syncing, kept beside `library.json`.
struct CampaignSyncState: Codable, Equatable {
    /// The iCloud user these entries describe.
    var account: String?
    var entries: [String: CampaignSyncEntry] = [:]
    var held: [String: HeldCampaignRecord] = [:]

    /// The saved state, or an empty one, which sends everything and merges what the server holds.
    static func load(from url: URL) -> CampaignSyncState {
        (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(CampaignSyncState.self, from: $0) }
            ?? CampaignSyncState()
    }

    func save(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }
}
