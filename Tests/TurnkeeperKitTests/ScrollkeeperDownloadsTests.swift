import Foundation
import TablesideShared
import Testing
@testable import TurnkeeperKit

/// Finding Scrollkeeper's downloads in the Tableside Toolkit's App Group (R2.3).
@Suite final class ScrollkeeperDownloadsTests {
    private let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("Scrollkeeper-\(UUID().uuidString)", isDirectory: true)
    private var files: URL { folder.appendingPathComponent("Files", isDirectory: true) }

    init() throws {
        try FileManager.default.createDirectory(at: files.appendingPathComponent("Monster Core"),
                                                withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: folder)
    }

    private func writeLibrary(isShared: Bool) throws {
        let library = ScrollkeeperLibrary(generatedAt: Date(),
                                          downloadFolder: .init(isShared: isShared, path: isShared ? nil : "/Chosen"),
                                          titles: [])
        try library.encoded().write(to: folder.appendingPathComponent(ScrollkeeperLibrary.fileName))
    }

    @Test func usesTheDownloadsTheLibraryListPointsTo() throws {
        try writeLibrary(isShared: true)
        #expect(ScrollkeeperDownloads.folder(in: folder) == files)
    }

    @Test func leavesAFolderChosenInScrollkeeperToTheUser() throws {
        try writeLibrary(isShared: false)
        #expect(ScrollkeeperDownloads.folder(in: folder) == nil)
    }

    @Test func usesTheGroupsFilesWithoutAListItCanRead() throws {
        try Data(#"{"formatVersion": 99}"#.utf8).write(to: folder.appendingPathComponent(ScrollkeeperLibrary.fileName))
        #expect(ScrollkeeperDownloads.folder(in: folder) == files)
    }

    @Test func asksWhenTheGroupHasNoDownloads() throws {
        try FileManager.default.removeItem(at: files.appendingPathComponent("Monster Core"))
        #expect(ScrollkeeperDownloads.folder(in: folder) == nil)
        #expect(ScrollkeeperDownloads.folder(in: nil) == nil)
    }
}
