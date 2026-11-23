import Foundation

/// A deleted campaign or scenario takes what's in it along, however late that arrives. A conflict copy made on
/// another device can land after the delete, and would otherwise live on, unseen, under a parent that's gone.
extension Library {
    /// Marks what's inside a deleted campaign or scenario deleted at the parent's time, so that devices doing this
    /// on their own agree. The fight on screen, `activeSession`, isn't touched. Returns true when anything changed.
    @discardableResult
    public mutating func retireOrphans(keepingSession activeSession: UUID?) -> Bool {
        let deletedCampaigns = Self.deletionTimes(of: campaigns)
        let campaignChildren = [
            retire(\.parties, under: deletedCampaigns) { $0.campaignID },
            retire(\.scenarios, under: deletedCampaigns) { $0.campaignID },
            retire(\.sessions, under: deletedCampaigns) { $0.id == activeSession ? nil : $0.campaignID }
        ]
        let deletedScenarios = Self.deletionTimes(of: scenarios)
        let scenarioChildren = [
            retire(\.encounters, under: deletedScenarios) { $0.scenarioID },
            retire(\.handouts, under: deletedScenarios) { $0.scenarioID },
            retire(\.creatureNotes, under: deletedScenarios) { $0.scenarioID }
        ]
        return (campaignChildren + scenarioChildren).contains(true)
    }

    private static func deletionTimes<Record: LibraryRecord>(of records: [Record]) -> [UUID: Date] {
        Dictionary(records.compactMap { record in record.deletedAt.map { (record.id, $0) } }) { first, _ in first }
    }

    private mutating func retire<Record: LibraryRecord>(
        _ path: WritableKeyPath<Library, [Record]>, under deleted: [UUID: Date], parent: (Record) -> UUID?
    ) -> Bool {
        var hasChanged = false
        for index in self[keyPath: path].indices where self[keyPath: path][index].deletedAt == nil {
            guard let id = parent(self[keyPath: path][index]), let time = deleted[id] else { continue }
            self[keyPath: path][index].deletedAt = time
            self[keyPath: path][index].modifiedAt = max(self[keyPath: path][index].modifiedAt, time)
            hasChanged = true
        }
        return hasChanged
    }
}
