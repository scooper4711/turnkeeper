import CryptoKit
import Foundation

/// The kinds of library record Turnkeeper syncs in its own CloudKit zone. Custom creatures and pasted art aren't
/// among them: they live in the shared library, which `LibrarySync` syncs.
public enum CampaignRecordKind: String, CaseIterable, Sendable {
    case campaign, party, scenario, encounter, session, handout, creatureNote

    /// The CloudKit record type.
    var recordType: String {
        "Turnkeeper" + rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }
}

/// Names one synced record: its CloudKit record name is `<kind>-<UUID>`.
public struct CampaignRecordReference: Hashable, Sendable {
    public var kind: CampaignRecordKind
    public var id: UUID

    public init(kind: CampaignRecordKind, id: UUID) {
        self.kind = kind
        self.id = id
    }

    /// The reference a record name spells; nil for any other name.
    public init?(recordName: String) {
        guard let dash = recordName.firstIndex(of: "-"),
              let kind = CampaignRecordKind(rawValue: String(recordName[..<dash])),
              let id = UUID(uuidString: String(recordName[recordName.index(after: dash)...])) else { return nil }
        self.init(kind: kind, id: id)
    }

    public var recordName: String { "\(kind.rawValue)-\(id.uuidString)" }
}

extension LibraryRecord {
    /// A digest of what the record says, leaving out when it was stamped and which versions it has shared, so two
    /// devices that made the same edit get the same digest.
    func contentDigest() throws -> String {
        var content = self
        content.modifiedAt = Date(timeIntervalSinceReferenceDate: 0)
        content.sharedVersion = nil
        content.sharedVersions = nil
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return SHA256.hash(data: try encoder.encode(content)).map { String(format: "%02x", $0) }.joined()
    }
}

extension Library {
    /// Every record Turnkeeper syncs in its own zone, deleted ones included.
    var campaignSyncRecords: [(reference: CampaignRecordReference, record: any LibraryRecord)] {
        Self.entries(campaigns, .campaign) + Self.entries(parties, .party) + Self.entries(scenarios, .scenario)
            + Self.entries(encounters, .encounter) + Self.entries(sessions, .session)
            + Self.entries(handouts, .handout) + Self.entries(creatureNotes, .creatureNote)
    }

    /// The record a reference names.
    func campaignSyncRecord(_ reference: CampaignRecordReference) -> (any LibraryRecord)? {
        let id = reference.id
        switch reference.kind {
        case .campaign: return campaigns.first { $0.id == id }
        case .party: return parties.first { $0.id == id }
        case .scenario: return scenarios.first { $0.id == id }
        case .encounter: return encounters.first { $0.id == id }
        case .session: return sessions.first { $0.id == id }
        case .handout: return handouts.first { $0.id == id }
        case .creatureNote: return creatureNotes.first { $0.id == id }
        }
    }

    private static func entries<Record: LibraryRecord>(
        _ records: [Record], _ kind: CampaignRecordKind
    ) -> [(reference: CampaignRecordReference, record: any LibraryRecord)] {
        records.map { (CampaignRecordReference(kind: kind, id: $0.id), $0) }
    }
}
