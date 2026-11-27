import Foundation
import TablesideShared

/// The sheet file Turnkeeper shares with Pawn Shop where it can't send a link (R3.9.6).
public enum PawnSheetShareFile {
    /// The folder, inside the temporary one, that holds the files being shared.
    static let folderName = "Shared Pawn Sheets"

    /// Writes the request as a sheet file named after its title and returns where it is. Each file gets a folder
    /// of its own, so two sheets with one title never overwrite each other while both are being shared. The
    /// system empties the temporary folder by itself.
    /// - Parameter readerVersion: The version of the PDF reader behind the art library.
    public static func write(
        _ request: PawnSheetRequest, readerVersion: Int?,
        in temporaryFolder: URL = FileManager.default.temporaryDirectory
    ) throws -> URL {
        let folder = temporaryFolder.appendingPathComponent(folderName, isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let file = folder.appendingPathComponent(request.sheetFileName)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try request.sheetFile(readerVersion: readerVersion).write(to: file, options: .atomic)
        } catch {
            throw PawnSheetShareError.notWritten(title: request.title, reason: error.localizedDescription)
        }
        return file
    }
}

/// Why a pawn sheet couldn't be shared.
public enum PawnSheetShareError: Error, Equatable, LocalizedError {
    case notWritten(title: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .notWritten(let title, let reason):
            "Sharing the pawn sheet “\(title)” failed: its file couldn't be written. \(reason)"
        }
    }
}
