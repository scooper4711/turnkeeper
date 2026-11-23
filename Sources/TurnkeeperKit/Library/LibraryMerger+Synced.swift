import Foundation

/// A record as it arrived from iCloud, with the digest of the version both sides last agreed on.
struct SyncedPayload {
    var payload: Data
    var kind: CampaignRecordKind
    var baseDigest: String?
}

/// Merging one record that arrived through iCloud.
///
/// Devices syncing all the time pass `sharedVersions`' cap quickly, so here the version both last agreed on (the
/// base) says who changed what. Without a base, on a library's first sync, `sharedVersions` still answers. Two
/// versions that say the same thing are never a conflict, however differently they are stamped.
extension LibraryMerger {
    /// Merges a record that arrived as JSON into `library`, and returns the digest of the received version,
    /// which is the new base.
    @discardableResult
    static func mergeSynced(
        _ incoming: SyncedPayload, into library: inout Library, summary: inout MergeSummary
    ) throws -> String {
        let (payload, baseDigest) = (incoming.payload, incoming.baseDigest)
        let decoder = JSONDecoder()
        switch incoming.kind {
        case .campaign:
            return try mergeSynced(try decoder.decode(Campaign.self, from: payload), into: &library.campaigns,
                                   baseDigest: baseDigest, summary: &summary)
        case .party:
            return try mergeSynced(try decoder.decode(Party.self, from: payload), into: &library.parties,
                                   baseDigest: baseDigest, summary: &summary,
                                   rules: MergeRules(combine: Party.merging(newer:older:)))
        case .scenario:
            return try mergeSynced(try decoder.decode(Scenario.self, from: payload), into: &library.scenarios,
                                   baseDigest: baseDigest, summary: &summary, rules: MergeRules(copy: conflictCopy))
        case .encounter:
            return try mergeSynced(try decoder.decode(Encounter.self, from: payload), into: &library.encounters,
                                   baseDigest: baseDigest, summary: &summary, rules: MergeRules(copy: conflictCopy))
        case .session:
            return try mergeSynced(try decoder.decode(CombatSession.self, from: payload), into: &library.sessions,
                                   baseDigest: baseDigest, summary: &summary)
        case .handout:
            return try mergeSynced(try decoder.decode(Handout.self, from: payload), into: &library.handouts,
                                   baseDigest: baseDigest, summary: &summary)
        case .creatureNote:
            return try mergeSynced(try decoder.decode(CreatureNote.self, from: payload), into: &library.creatureNotes,
                                   baseDigest: baseDigest, summary: &summary)
        }
    }

    private static func mergeSynced<Record: LibraryRecord>(
        _ theirs: Record, into local: inout [Record], baseDigest: String?, summary: inout MergeSummary,
        rules: MergeRules<Record> = MergeRules()
    ) throws -> String {
        let theirsDigest = try theirs.contentDigest()
        guard let index = local.firstIndex(where: { $0.id == theirs.id }) else {
            local.append(theirs.received(alongside: nil))
            if !theirs.isDeleted { summary.added += 1 }
            return theirsDigest
        }
        let ours = local[index]
        let oursDigest = try ours.contentDigest()
        guard oursDigest != theirsDigest else {
            let (later, earlier) = theirs.modifiedAt > ours.modifiedAt ? (theirs, ours) : (ours, theirs)
            local[index] = later.received(alongside: earlier)
            return theirsDigest
        }
        let sides = baseDigest.map {
            MergeSides(oursUnchanged: oursDigest == $0, theirsUnchanged: theirsDigest == $0)
        } ?? MergeSides(oursUnchanged: theirs.hasShared(ours.modifiedAt),
                        theirsUnchanged: ours.hasShared(theirs.modifiedAt))
        settle(MergeDecision(theirs: theirs, index: index, sides: sides, rules: rules), in: &local, summary: &summary)
        return theirsDigest
    }
}
