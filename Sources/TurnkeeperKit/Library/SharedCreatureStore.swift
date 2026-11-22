import ArtExtraction
import Bestiary
import CreatureArt
import Foundation
import SharedLibraries

/// Keeps the library's custom creatures and pasted art in the library the Tableside apps share (shared libraries
/// R4). `Library` stays the model the app edits: `push` writes what changed, `pull` reads what other apps changed.
/// Like `SharedLibrary`, it is used from one thread at a time, the app's main actor.
public final class SharedCreatureStore {
    public let shared: SharedLibrary
    private let positionFile: URL
    /// The rows as last read or written, so only real changes are written.
    private var knownCreatures: [UUID: CustomCreatureRecord] = [:]
    private var knownArt: [UUID: CustomArtRecord] = [:]
    private var position: Int64 = 0
    private var hasPulled = false

    /// `positionFile` remembers how far this app has read this library's deletions, between launches.
    public init(shared: SharedLibrary, positionFile: URL) throws {
        self.shared = shared
        self.positionFile = positionFile
        position = try StoredPosition.read(from: positionFile, folder: shared.folder) ?? shared.changeCounter()
        try readKnownRows()
    }

    /// The folder of custom art's images.
    public var artStore: ArtStore {
        ArtStore(directory: shared.customFile("placeholder").deletingLastPathComponent())
    }

    /// Moves the app's custom creatures, pasted art and PDF art library in, once (R6). A failure leaves the app's
    /// own library in place, and the next launch tries again (R6.5).
    public func moveIn(_ library: Library, artFolder: URL, pastedArtFolder: URL) throws {
        guard try !shared.hasMovedIn(.turnkeeper) else { return }
        var move = LibraryMove(app: .turnkeeper, artFolder: artFolder)
        let live = library.customArt.filter { !$0.isDeleted }
        move.customCreatures = try library.customCreatures.filter { !$0.isDeleted }.map(Self.row)
        move.customArt = try live.map(Self.row)
        move.customArtFolder = pastedArtFolder
        move.creatureArt = Dictionary(live.map { ($0.subject, .custom($0.id)) }) { _, newer in newer }
        _ = try shared.moveIn(move)
        try readKnownRows()
    }

    /// Writes the creatures and art that changed in `library`, and removes those deleted there.
    public func push(_ library: Library) throws {
        for custom in library.customCreatures where !custom.isDeleted {
            let row = try Self.row(custom)
            guard knownCreatures[custom.id] != row else { continue }
            try shared.save(row)
            knownCreatures[custom.id] = row
        }
        try pushArt(library)
        for custom in library.customCreatures where custom.isDeleted && knownCreatures[custom.id] != nil {
            try shared.removeCustomCreature(id: custom.id)
            knownCreatures[custom.id] = nil
        }
    }

    /// Reads the shared rows into `library`, and takes creatures another app deleted out of every encounter (R4.9).
    /// Only deletions the library recorded count: a creature merely absent may be in another build's library.
    @discardableResult
    public func pull(into library: inout Library) throws -> LibraryChanges {
        let changes = try shared.changes(since: position)
        guard !hasPulled || !changes.isEmpty else { return changes }
        hasPulled = true
        let rows = try shared.customCreatures()
        let merged = rows.compactMap { Self.creature(from: $0, replacing: library.customCreatures) }
        knownCreatures = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
        let liveIDs = Set(rows.map(\.id))
        library.customCreatures = library.customCreatures.filter { $0.isDeleted && !liveIDs.contains($0.id) } + merged
        try pullArt(into: &library)
        for id in (changes.deletions[.customCreatures] ?? []).compactMap(UUID.init(uuidString:))
        where !liveIDs.contains(id) {
            library.removeFromEncounters(key: CustomCreature.keyPrefix + id.uuidString)
        }
        position = changes.counter
        return changes
    }

    /// Remembers how far deletions were read; called once the library holding their effects has been saved.
    public func savePosition() throws {
        try StoredPosition(folder: shared.folder.path, counter: position).write(to: positionFile)
    }

    private func readKnownRows() throws {
        knownCreatures = Dictionary(uniqueKeysWithValues: try shared.customCreatures().map { ($0.id, $0) })
        knownArt = Dictionary(uniqueKeysWithValues: try shared.customArt().map { ($0.id, $0) })
    }

    // MARK: Art

    private func pushArt(_ library: Library) throws {
        for art in library.customArt where !art.isDeleted {
            let row = try Self.row(art)
            guard knownArt[art.id] != row else { continue }
            try shared.save(row)
            try shared.setCreatureArt(.custom(art.id), for: art.subject)
            knownArt[art.id] = row
        }
        let choices = try shared.creatureArt()
        for art in library.customArt where art.isDeleted && knownArt[art.id] != nil {
            if choices[art.subject] == .custom(art.id) { try shared.setCreatureArt(nil, for: art.subject) }
            try shared.removeCustomArt(id: art.id)
            knownArt[art.id] = nil
        }
    }

    private func pullArt(into library: inout Library) throws {
        let choices = try shared.creatureArt()
        let subjects = Dictionary(choices.compactMap { subject, choice -> (UUID, String)? in
            if case .custom(let id) = choice { return (id, subject) }
            return nil
        }) { first, _ in first }
        let rows = try shared.customArt()
        let merged = rows.compactMap { Self.art(from: $0, subject: subjects[$0.id], in: shared) }
        let liveIDs = Set(merged.map(\.id))
        knownArt = Dictionary(uniqueKeysWithValues: try merged.map { ($0.id, try Self.row($0)) })
        library.customArt = library.customArt.filter { $0.isDeleted && !liveIDs.contains($0.id) } + merged
    }

    // MARK: Rows

    /// The row for a creature. A name-only creature keeps an empty record and no game, so it stays one (R4.10).
    static func row(_ custom: CustomCreature) throws -> CustomCreatureRecord {
        let size = CreatureSize(trait: custom.creature.traits.size)
        guard custom.hasStatBlock else {
            return CustomCreatureRecord(id: custom.id, name: custom.creature.name, campaignID: nil,
                                        sharedVersion: custom.sharedVersion, record: Data(), size: size)
        }
        return CustomCreatureRecord(id: custom.id, name: custom.creature.name, campaignID: custom.campaignID,
                                    sharedVersion: custom.sharedVersion, record: try encoded(custom),
                                    game: custom.creature.game == .starfinder ? .starfinder : .pathfinder, size: size)
    }

    static func row(_ art: CustomArt) throws -> CustomArtRecord {
        CustomArtRecord(id: art.id, fileName: art.fileName, sharedVersion: art.sharedVersion, record: try encoded(art))
    }

    /// The creature a row holds, with the row's name and size over the record's (R4.4a, R4.7). A change made in
    /// another app gets a new modification time, so sharing the library carries it. Nil for a record this version
    /// can't read, which is left alone in the library rather than overwritten.
    static func creature(from row: CustomCreatureRecord, replacing existing: [CustomCreature]) -> CustomCreature? {
        let current = existing.first { $0.id == row.id }
        var custom: CustomCreature
        if row.hasStatBlock {
            guard let stored = try? JSONDecoder().decode(CustomCreature.self, from: row.record) else { return nil }
            custom = stored
        } else {
            custom = CustomCreature(nameOnlyID: row.id, name: row.name, size: row.size?.trait ?? "")
            custom.modifiedAt = current?.modifiedAt ?? .distantPast
        }
        let baseline = row.hasStatBlock ? custom.creature : current?.creature ?? custom.creature
        custom.creature = custom.creature.applying(name: row.name, size: row.size)
        if custom.creature != baseline { custom.modifiedAt = ChangeClock.now() }
        custom.sharedVersion = row.sharedVersion
        return custom
    }

    /// The art a row holds. Art added in Pawn Shop has no record: it takes its subject from the art chosen, and its
    /// file's date as a modification time that stays the same between launches.
    static func art(from row: CustomArtRecord, subject: String?, in shared: SharedLibrary) -> CustomArt? {
        if let art = try? JSONDecoder().decode(CustomArt.self, from: row.record) { return art }
        guard let subject else { return nil }
        let file = shared.customFile(row.fileName)
        let values = try? file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        var art = CustomArt(subject: subject, fileName: row.fileName, byteCount: values?.fileSize ?? 0)
        art.id = row.id
        art.modifiedAt = values?.contentModificationDate ?? .distantPast
        art.sharedVersion = row.sharedVersion
        return art
    }

    private static func encoded(_ value: some Encodable) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }
}

/// How far this app has read a library's deletions. It names the library's folder: a different library (an ad hoc
/// build's own) starts from its current counter, so its history removes nothing from encounters.
private struct StoredPosition: Codable {
    var folder: String
    var counter: Int64

    static func read(from file: URL, folder: URL) throws -> Int64? {
        guard let data = try? Data(contentsOf: file),
              let stored = try? JSONDecoder().decode(Self.self, from: data), stored.folder == folder.path
        else { return nil }
        return stored.counter
    }

    func write(to file: URL) throws {
        try JSONEncoder().encode(self).write(to: file, options: .atomic)
    }
}

public extension Library {
    /// What `library.json` keeps once the shared library holds the rest: the deletions, which sharing carries to
    /// other devices.
    func keepingOnlyLocalRecords() -> Library {
        var kept = self
        kept.customCreatures = customCreatures.filter(\.isDeleted)
        kept.customArt = customArt.filter(\.isDeleted)
        return kept
    }
}
