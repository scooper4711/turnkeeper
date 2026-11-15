import Foundation
import Network

/// Shares this device's player screen with any number of following devices on the local network: each joins
/// with the code, gets the current snapshot at once, then every snapshot published, and the art it asks for.
public final class TableHost: @unchecked Sendable {
    /// More followers than any table has players; beyond it a device is refused.
    public static let maximumFollowers = 24
    /// Followers only send a code and art requests, so anything longer is refused.
    static let incomingLimit = 64 * 1024

    public let code: String
    private let listener: NWListener
    private let queue = DispatchQueue(label: "turnkeeper.table.host")
    private let followers = Followers()
    private let art: @Sendable (String) async -> Data?
    private let followersChanged: @Sendable ([String]) -> Void

    /// - Parameters:
    ///   - name: The name other devices see, or nil to listen without advertising (for tests).
    ///   - code: The code a follower must enter.
    ///   - art: The image file for an art ID from a snapshot, or nil when there is none.
    ///   - followersChanged: Called with the followers' names whenever one joins or leaves.
    public init(name: String?, code: String, art: @escaping @Sendable (String) async -> Data?,
                followersChanged: @escaping @Sendable ([String]) -> Void = { _ in }) throws {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        listener = try NWListener(using: parameters)
        if let name { listener.service = NWListener.Service(name: name, type: tableServiceType) }
        self.code = code
        self.art = art
        self.followersChanged = followersChanged
    }

    /// Starts listening and returns the port once ready.
    public func start() async throws -> NWEndpoint.Port {
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { return }
            let channel = MessageChannel<TableMessage>(connection: connection, queue: self.queue,
                                                       limit: Self.incomingLimit)
            Task { await self.serve(channel) }
        }
        return try await withCheckedThrowingContinuation { continuation in
            let once = Once()
            listener.stateUpdateHandler = { [listener] state in
                switch state {
                case .ready: once.run { continuation.resume(returning: listener.port ?? 0) }
                case let .failed(error):
                    once.run { continuation.resume(throwing: TableError.connectionLost("\(error)")) }
                default: break
                }
            }
            listener.start(queue: queue)
        }
    }

    /// Stops sharing and drops every follower.
    public func stop() {
        listener.cancel()
        Task { await followers.removeAll() }
    }

    /// Sends what the players are shown now to every follower, and to those who join later.
    public func publish(_ content: TableSnapshot.Content) async {
        let (snapshot, channels) = await followers.publish(content)
        for channel in channels {
            try? await channel.send(.snapshot(snapshot))
        }
    }

    private func serve(_ channel: MessageChannel<TableMessage>) async {
        let id = UUID()
        do {
            try await channel.open()
            guard case let .join(entered, name) = try await channel.receive() else { return channel.close() }
            if let reason = await refusal(entered) {
                try await channel.send(.refused(reason: reason))
                return channel.close()
            }
            let snapshot = await followers.add(Follower(id: id, name: name, channel: channel))
            followersChanged(await followers.names)
            try await channel.send(.welcome)
            if let snapshot { try await channel.send(.snapshot(snapshot)) }
            while true { try await answer(try await channel.receive(), on: channel) }
        } catch {
            channel.close()
            await followers.remove(id)
            followersChanged(await followers.names)
        }
    }

    /// Why a device with this code can't join; nil when it can. A wrong code waits a moment first, so the four
    /// digits can't be run through quickly.
    private func refusal(_ entered: String) async -> String? {
        guard PairingCode.matches(entered, code) else {
            try? await Task.sleep(for: .seconds(1))
            return "the code doesn't match the one shown on the other device."
        }
        guard await followers.count < Self.maximumFollowers else {
            return "\(Self.maximumFollowers) devices are following already."
        }
        return nil
    }

    private func answer(_ message: TableMessage, on channel: MessageChannel<TableMessage>) async throws {
        guard case let .needArt(id) = message else { return }
        // Only what is on show: a follower can't ask this device for any other file.
        let image = await followers.isOnShow(id) ? await art(id) : nil
        try await channel.send(.art(id: id, image: image ?? Data()))
    }
}

struct Follower: Sendable {
    var id: UUID
    var name: String
    var channel: MessageChannel<TableMessage>
}

/// The devices following, and the snapshot a newcomer starts from.
actor Followers {
    private var followers: [Follower] = []
    private var latest: TableSnapshot?

    var count: Int { followers.count }
    var names: [String] { followers.map(\.name) }

    /// Whether the newest snapshot shows this art.
    func isOnShow(_ artID: String) -> Bool {
        latest?.content.artIDs.contains(artID) ?? false
    }

    /// Adds a follower and returns the snapshot to send it first.
    func add(_ follower: Follower) -> TableSnapshot? {
        followers.append(follower)
        return latest
    }

    func remove(_ id: UUID) {
        followers.removeAll { $0.id == id }
    }

    func removeAll() {
        followers.forEach { $0.channel.close() }
        followers = []
    }

    /// Numbers the next snapshot and returns it with the channels to send it on.
    func publish(_ content: TableSnapshot.Content) -> (TableSnapshot, [MessageChannel<TableMessage>]) {
        let snapshot = TableSnapshot(sequence: (latest?.sequence ?? 0) + 1, content: content)
        latest = snapshot
        return (snapshot, followers.map(\.channel))
    }
}
