import Bestiary
import CoreGraphics
import ImageIO
import Observation
import TurnkeeperKit
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#endif

/// Shares this device's player screen with the players' own devices (R9): whatever `PlayerDisplay` holds, a
/// handout or the fight on the board, goes to every device following, with the art it asks for.
@Observable
@MainActor
final class TableSharing {
    static let shared = TableSharing()
    private static let codeKey = "tableShareCode"

    /// The app's model, for the creatures' card backs and art.
    var model: AppModel?
    /// The code players enter, kept for this device so a table's regulars don't need a new one every session.
    let code: String
    /// The names of the devices following.
    private(set) var followers: [String] = []
    /// Why sharing couldn't start; empty when it did.
    private(set) var errorMessage = ""
    private(set) var isOn = false
    @ObservationIgnored private var host: TableHost?

    private init() {
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--share-table"), arguments.indices.contains(index + 1) {
            // For UI tests and screenshots: shares from launch with this code.
            code = arguments[index + 1]
            Task { await start() }
        } else if let saved = UserDefaults.standard.string(forKey: Self.codeKey), saved.count == 4 {
            code = saved
        } else {
            var generator = SystemRandomNumberGenerator()
            code = PairingCode.make(using: &generator)
            UserDefaults.standard.set(code, forKey: Self.codeKey)
        }
    }

    func start() async {
        guard host == nil else { return }
        do {
            let host = try TableHost(name: DeviceName.current, code: code, art: { id in
                await TableSharing.shared.imageFile(for: id)
            }, followersChanged: { names in
                Task { @MainActor in TableSharing.shared.followers = names }
            })
            _ = try await host.start()
            self.host = host
            isOn = true
            errorMessage = ""
            refresh()
        } catch {
            errorMessage = "Sharing the player screen failed: \(error.localizedDescription)"
        }
    }

    func stop() {
        host?.stop()
        host = nil
        isOn = false
        followers = []
    }

    /// Listens again after the app was in the background, where iOS closes the listener. The followers come
    /// back on their own.
    func resume() async {
        guard isOn else { return }
        stop()
        await start()
    }

    /// Sends what the players are shown now.
    func refresh() {
        guard let host else { return }
        let content = content
        Task { await host.publish(content) }
    }

    /// What the players are shown: the handout on show, else the fight on the board, whether or not this
    /// device's own player screen is on.
    private var content: TableSnapshot.Content {
        let display = PlayerDisplay.shared
        if let handout = display.handout { return .handout(name: handout.name, artID: handout.imagePath) }
        guard let fight = display.fight else { return .waiting }
        return .fight(fight) { key in card(for: key) }
    }

    private func card(for key: String) -> TableCard? {
        guard let entry = model?.entry(key) else { return nil }
        return TableCard(name: entry.name, game: entry.game, traits: entry.traits.traits,
                         artID: entry.art.portrait.isEmpty ? entry.art.token : entry.art.portrait)
    }

    /// The image file for an art path: the file itself for pasted art and handouts, else the picture drawn
    /// from the user's PDFs as a PNG, which keeps a pawn's cut-out edges.
    private func imageFile(for path: String) async -> Data? {
        guard let model else { return nil }
        if !path.hasPrefix(LibraryArtMatcher.pathPrefix), let url = model.artURL(for: path) {
            return try? Data(contentsOf: url)
        }
        guard let picture = await model.artPicture(for: path, maxPixels: Self.sharedArtPixels) else { return nil }
        return ImageFile.png(picture)
    }

    /// Enough for a card back on a phone or an iPad, and quick to send.
    private static let sharedArtPixels = 1024
}

/// Pictures as image files, to send to a following device and read there.
enum ImageFile {
    static func png(_ image: CGImage) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? output as Data : nil
    }

    static func picture(_ file: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(file as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}

/// This device's name, as other devices see it when syncing or following.
enum DeviceName {
    @MainActor static var current: String {
        #if os(macOS)
        return Host.current().localizedName ?? "Mac"
        #else
        return UIDevice.current.name
        #endif
    }
}
