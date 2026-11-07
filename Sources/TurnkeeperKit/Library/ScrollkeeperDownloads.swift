import Foundation
import TablesideShared

/// Where Turnkeeper finds Scrollkeeper's downloads without asking: on the Mac, a sandboxed Scrollkeeper keeps them in
/// the Tableside Toolkit's App Group and says so in its library list (`ScrollkeeperLibrary`). Elsewhere, or when the
/// user chose another download folder in Scrollkeeper, the user picks the folder.
public enum ScrollkeeperDownloads {
    /// The downloads in Scrollkeeper's folder in the App Group: where its library list says they are, or without a
    /// list Turnkeeper can read, the group's `Files` when it holds anything. Nil when the user has to pick them.
    public static func folder(in scrollkeeperFolder: URL? = ToolkitGroup.scrollkeeperFolder()) -> URL? {
        guard let folder = scrollkeeperFolder else { return nil }
        if case let .loaded(library) = ScrollkeeperLibrary.read(from: folder) {
            return library.downloadFolderURL(in: folder).flatMap { isListable($0) ? $0 : nil }
        }
        let files = folder.appendingPathComponent("Files", isDirectory: true)
        let contents = try? FileManager.default.contentsOfDirectory(atPath: files.path)
        return (contents ?? []).contains { !$0.hasPrefix(".") } ? files : nil
    }

    private static func isListable(_ folder: URL) -> Bool {
        (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) != nil
    }
}
