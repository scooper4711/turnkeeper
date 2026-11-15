import CoreGraphics
import Observation
import TurnkeeperKit
import Foundation

/// Follows another device's player screen (R9): joins with its code, keeps what it shows, asks for art as it is
/// needed, and goes back on its own when the connection breaks, as it does whenever this app is left for another.
@Observable
@MainActor
final class TableFollowing {
    static let shared = TableFollowing()
    private static let nameKey = "followedTableName"
    private static let codeKey = "followedTableCode"

    enum Phase: Equatable {
        case idle
        case joining
        case following
        /// The connection broke; trying again.
        case reconnecting
        case refused(String)
    }

    private(set) var phase = Phase.idle
    /// What the sharing device shows now, or showed last while reconnecting.
    private(set) var content = TableSnapshot.Content.waiting
    /// The table being followed.
    private(set) var table: TablePeer?
    /// True while the viewer covers the app.
    var isViewerOpen = false
    /// Counts the times the table was joined, so art that failed to load while reconnecting is asked for again.
    private(set) var connections = 0

    @ObservationIgnored private var code = ""
    @ObservationIgnored private var follower: TableFollower?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var failures = 0
    /// Art received, by ID. Kept in memory only: it is the sharing device's user's, never saved here.
    @ObservationIgnored private var pictures: [String: CGImage] = [:]
    @ObservationIgnored private var waiting: [String: [CheckedContinuation<CGImage?, Never>]] = [:]

    private init() {
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--follow-table"), arguments.indices.contains(index + 2) {
            // For UI tests and screenshots: follows from launch. "self" is this device.
            let name = arguments[index + 1] == "self" ? DeviceName.current : arguments[index + 1]
            join(TablePeer(name: name), code: arguments[index + 2])
        }
    }

    /// The table followed last and its code, to offer again.
    var remembered: (table: TablePeer, code: String)? {
        let defaults = UserDefaults.standard
        guard let name = defaults.string(forKey: Self.nameKey), let code = defaults.string(forKey: Self.codeKey)
        else { return nil }
        return (TablePeer(name: name), code)
    }

    func join(_ table: TablePeer, code: String) {
        leave()
        self.table = table
        self.code = code
        isViewerOpen = true
        connect()
    }

    func leave() {
        disconnect()
        table = nil
        isViewerOpen = false
        phase = .idle
        content = .waiting
        pictures = [:]
    }

    /// Makes a new connection now: after another app was in front, the old one is gone or about to be.
    func returnedToForeground() {
        guard table != nil, phase != .idle, !isRefused else { return }
        disconnect()
        failures = 0
        connect()
    }

    /// A piece of art from the sharing device, asked for once and kept while following.
    func picture(for id: String) async -> CGImage? {
        if let picture = pictures[id] { return picture }
        guard let follower, phase == .following else { return nil }
        let isFirst = waiting[id] == nil
        return await withCheckedContinuation { continuation in
            waiting[id, default: []].append(continuation)
            if isFirst { Task { await follower.requestArt(id) } }
        }
    }

    private var isRefused: Bool {
        if case .refused = phase { return true }
        return false
    }

    private func connect() {
        guard let table else { return }
        phase = failures == 0 && content == .waiting ? .joining : .reconnecting
        task = Task { [code] in
            while !Task.isCancelled {
                let follower = TableFollower(endpoint: table.endpoint, code: code, name: DeviceName.current)
                self.follower = follower
                let ended = await Self.follow(follower)
                guard !Task.isCancelled else { return }
                if case let .refused(reason) = ended {
                    phase = .refused(reason)
                    return
                }
                failures += 1
                phase = .reconnecting
                answerWaiting(with: nil)
                try? await Task.sleep(for: .seconds(ReconnectDelay.seconds(afterFailures: failures)))
            }
        }
    }

    /// Follows until the connection ends, and returns why it ended.
    private nonisolated static func follow(_ follower: TableFollower) async -> TableError {
        do {
            try await follower.follow(joined: { await shared.joined() }, deliver: { await shared.handle($0) })
        } catch {
            return error as? TableError ?? .connectionLost("\(error)")
        }
    }

    private func joined() {
        phase = .following
        failures = 0
        connections += 1
        if let table {
            UserDefaults.standard.set(table.name, forKey: Self.nameKey)
            UserDefaults.standard.set(code, forKey: Self.codeKey)
        }
    }

    private func handle(_ event: TableFollower.Event) {
        switch event {
        case let .snapshot(snapshot):
            content = snapshot.content
        case let .art(id, image):
            let picture = ImageFile.picture(image)
            pictures[id] = picture
            waiting.removeValue(forKey: id)?.forEach { $0.resume(returning: picture) }
        }
    }

    private func disconnect() {
        task?.cancel()
        task = nil
        follower?.stop()
        follower = nil
        answerWaiting(with: nil)
    }

    private func answerWaiting(with picture: CGImage?) {
        let continuations = waiting.values.flatMap { $0 }
        waiting = [:]
        continuations.forEach { $0.resume(returning: picture) }
    }
}
