import CloudKit
import Foundation

/// A record as it came from the server.
struct RemoteCampaignRecord {
    var reference: CampaignRecordReference
    var format: Int64
    var payload: Data
    var systemFields: Data
    /// A handout's image: the name it is stored under and where CloudKit put the download.
    var imageName: String?
    var imageFile: URL?
}

/// What goes into a CloudKit record.
struct OutgoingCampaignRecord {
    var reference: CampaignRecordReference
    var payload: Data
    var systemFields: Data?
    var imageName: String?
    var imageFile: URL?
}

/// Turns library records into CloudKit records and back: one per record, in the zone `Turnkeeper` of the suite's
/// container, with the fields `format`, `payload` (or `payloadAsset` when large), `imageName` and `image`.
struct CampaignRecordCoder {
    static let zoneName = "Turnkeeper"
    static let zone = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
    /// The layout of a record's fields. A record in a later layout is held, and its record here isn't sent over it.
    static let format: Int64 = 1
    /// Larger payloads go up as an asset: a CloudKit record holds 1 MB, and a party's sheets can pass that.
    static let inlinePayloadLimit = 512 * 1024

    /// Where large payloads wait until the server has taken them.
    let outgoingFolder: URL

    static func recordID(of reference: CampaignRecordReference) -> CKRecord.ID {
        CKRecord.ID(recordName: reference.recordName, zoneID: zone)
    }

    /// The reference a record ID names; nil for another zone or another kind of name.
    static func reference(of recordID: CKRecord.ID) -> CampaignRecordReference? {
        guard recordID.zoneID == zone else { return nil }
        return CampaignRecordReference(recordName: recordID.recordName)
    }

    func record(for outgoing: OutgoingCampaignRecord) throws -> CKRecord {
        let record = outgoing.systemFields.flatMap(Self.record(withSystemFields:))
            ?? CKRecord(recordType: outgoing.reference.kind.recordType, recordID: Self.recordID(of: outgoing.reference))
        record["format"] = Self.format
        if outgoing.payload.count > Self.inlinePayloadLimit {
            record["payload"] = nil
            record["payloadAsset"] = CKAsset(fileURL: try writeOutgoing(outgoing))
        } else {
            record["payload"] = outgoing.payload
            record["payloadAsset"] = nil
        }
        record["imageName"] = outgoing.imageName
        record["image"] = outgoing.imageFile.map(CKAsset.init(fileURL:))
        return record
    }

    /// What a server record holds; nil when it isn't one of Turnkeeper's or its payload can't be read.
    static func remote(from record: CKRecord) -> RemoteCampaignRecord? {
        guard let reference = reference(of: record.recordID), record.recordType == reference.kind.recordType,
              let payload = payload(of: record) else { return nil }
        return RemoteCampaignRecord(reference: reference, format: record["format"] as? Int64 ?? format,
                                    payload: payload, systemFields: systemFields(of: record),
                                    imageName: record["imageName"] as? String,
                                    imageFile: (record["image"] as? CKAsset)?.fileURL)
    }

    func removeOutgoingFile(of reference: CampaignRecordReference) {
        try? FileManager.default.removeItem(at: outgoingFile(of: reference))
    }

    func removeOutgoingFiles() {
        try? FileManager.default.removeItem(at: outgoingFolder)
    }

    /// A record's system fields, archived.
    static func systemFields(of record: CKRecord) -> Data {
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: archiver)
        archiver.finishEncoding()
        return archiver.encodedData
    }

    static func record(withSystemFields data: Data) -> CKRecord? {
        guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        unarchiver.requiresSecureCoding = true
        defer { unarchiver.finishDecoding() }
        return CKRecord(coder: unarchiver)
    }

    private static func payload(of record: CKRecord) -> Data? {
        if let inline = record["payload"] as? Data { return inline }
        return (record["payloadAsset"] as? CKAsset)?.fileURL.flatMap { try? Data(contentsOf: $0) }
    }

    private func writeOutgoing(_ outgoing: OutgoingCampaignRecord) throws -> URL {
        try FileManager.default.createDirectory(at: outgoingFolder, withIntermediateDirectories: true)
        let file = outgoingFile(of: outgoing.reference)
        try outgoing.payload.write(to: file, options: .atomic)
        return file
    }

    private func outgoingFile(of reference: CampaignRecordReference) -> URL {
        outgoingFolder.appendingPathComponent(reference.recordName + ".json")
    }
}
