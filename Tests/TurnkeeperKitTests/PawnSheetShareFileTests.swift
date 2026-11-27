import Foundation
import TablesideShared
import Testing
@testable import TurnkeeperKit

@Suite("The sheet file shared with Pawn Shop")
struct PawnSheetShareFileTests {
    private let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("PawnSheetShareFileTests-\(UUID().uuidString)", isDirectory: true)
    private let request = PawnSheetRequest(title: "Trouble in Otari: Docks", lines: [
        .init(name: "Goblin Warrior", count: 3, pawnID: UUID()), .init(name: "Spike Trap")
    ])

    private func cleanUp() { try? FileManager.default.removeItem(at: folder) }

    @Test("The file is named after the title and holds the request as a sheet")
    func writesTheSheet() throws {
        defer { cleanUp() }
        let file = try PawnSheetShareFile.write(request, readerVersion: 6, in: folder)
        #expect(file.lastPathComponent == "Trouble in Otari Docks.pawnsheet")
        let contents = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        #expect(contents["readerVersion"] as? Int == 6)
        #expect(contents["formatVersion"] as? Int == PawnSheetRequest.sheetFileFormatVersion)
        #expect((contents["entries"] as? [[String: Any]])?.count == 2)
    }

    @Test("Two sheets with one title don't overwrite each other")
    func keepsFilesApart() throws {
        defer { cleanUp() }
        let first = try PawnSheetShareFile.write(request, readerVersion: nil, in: folder)
        let second = try PawnSheetShareFile.write(request, readerVersion: nil, in: folder)
        #expect(first != second && first.lastPathComponent == second.lastPathComponent)
        #expect(FileManager.default.fileExists(atPath: first.path))
        #expect(first.path.hasPrefix(folder.appendingPathComponent(PawnSheetShareFile.folderName).path))
    }

    @Test("A folder that can't be made says which sheet failed")
    func saysWhatFailed() throws {
        defer { cleanUp() }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        // A file where the folder should go.
        let blocked = folder.appendingPathComponent("blocked")
        try Data().write(to: blocked)
        #expect { try PawnSheetShareFile.write(request, readerVersion: nil, in: blocked) } throws: { error in
            guard case .notWritten(let title, _) = error as? PawnSheetShareError else { return false }
            return title == "Trouble in Otari: Docks" && error.localizedDescription.contains("couldn't be written")
        }
    }
}
