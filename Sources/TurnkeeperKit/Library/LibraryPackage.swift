import Foundation
import UniformTypeIdentifiers

public extension UTType {
    /// A `.turnkeeper` file: a library package. It holds JSON but isn't declared as text, or Finder and Files
    /// would draw the start of the JSON as the file's picture in place of its icon.
    static let turnkeeperLibrary = UTType(exportedAs: "io.github.scooper4711.turnkeeper.library", conformingTo: .data)
}

/// The contents of a `.turnkeeper` file: some or all of a library.
public struct LibraryPackage: Codable, Sendable {
    public static let currentFormat = 1

    public var format: Int
    public var exportedAt: Date
    /// The bestiary import the creatures refer to, so a mismatch can be reported.
    public var bestiaryRevision: String
    public var library: Library
    /// The bytes of the pasted images the library's art records point to, by file name.
    public var images: [String: Data] = [:]

    public init(library: Library, bestiaryRevision: String, exportedAt: Date = Date()) {
        format = Self.currentFormat
        self.exportedAt = exportedAt
        self.bestiaryRevision = bestiaryRevision
        self.library = library
    }

    /// A package of what the GM checked in the export dialog (R1.2a).
    public init(picking selection: ExportSelection, from library: Library, bestiaryRevision: String) {
        self.init(library: library.exporting(selection), bestiaryRevision: bestiaryRevision)
    }

    private enum CodingKeys: String, CodingKey {
        case format, exportedAt, bestiaryRevision, library, images
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        format = try container.decode(Int.self, forKey: .format)
        exportedAt = try container.decode(Date.self, forKey: .exportedAt)
        bestiaryRevision = try container.decode(String.self, forKey: .bestiaryRevision)
        library = try container.decode(Library.self, forKey: .library)
        images = try container.decodeIfPresent([String: Data].self, forKey: .images) ?? [:]
    }

    /// The package with the images its records point to: handouts' from `store`, custom art's from `artStore`
    /// (the shared library's folder), or from `store` when the app keeps its art there.
    public func addingImages(from store: ArtStore, artStore: ArtStore? = nil) -> LibraryPackage {
        var package = self
        for fileName in library.liveHandoutFileNames { package.images[fileName] = store.data(for: fileName) }
        for fileName in library.liveArtFileNames { package.images[fileName] = (artStore ?? store).data(for: fileName) }
        return package
    }

    /// Puts art in the package with its image, for art the library doesn't hold as a record (R1.2b).
    public mutating func add(_ art: CustomArt, image: Data) {
        library.customArt.append(art)
        images[art.fileName] = image
    }

    /// The package with only the images that have these file names: those a library still points to once the
    /// package is merged into it.
    public func keepingImages(_ fileNames: Set<String>) -> LibraryPackage {
        var package = self
        package.images = images.filter { fileNames.contains($0.key) }
        return package
    }

    /// Writes the package's images that their store doesn't have yet; do this before merging the library.
    public func writeImages(to store: ArtStore, artStore: ArtStore? = nil) throws {
        let artFiles = Set(library.customArt.map(\.fileName))
        for (fileName, data) in images {
            let target = artFiles.contains(fileName) ? artStore ?? store : store
            if !target.contains(fileName) { try target.write(data, as: fileName) }
        }
    }

    /// JSON with sorted keys. Dates use the default encoding, seconds as a double, which round-trips
    /// exactly so modification times compare equal after a transfer.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> LibraryPackage {
        let decoder = JSONDecoder()
        let package = try decoder.decode(LibraryPackage.self, from: data)
        guard package.format <= currentFormat else { throw LibraryError.newerFormat(package.format) }
        return package
    }
}

public enum LibraryError: Error, LocalizedError, Equatable {
    case newerFormat(Int)

    public var errorDescription: String? {
        switch self {
        case let .newerFormat(format):
            return "Opening the library failed: it was saved in format \(format) by a newer Turnkeeper."
        }
    }
}
