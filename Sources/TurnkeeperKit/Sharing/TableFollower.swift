import Foundation
import Network

/// A device advertising its player screen.
public struct TablePeer: Identifiable, Hashable, Sendable {
    public var name: String

    public var id: String { name }

    public init(name: String) {
        self.name = name
    }

    /// Where to reach it. Made from the name alone, so a follower that remembers a table can go back to it
    /// without browsing again.
    public var endpoint: NWEndpoint {
        .service(name: name, type: tableServiceType, domain: "local.", interface: nil)
    }
}

/// Finds devices sharing their player screens.
public final class TableBrowser: @unchecked Sendable {
    private let browser = NWBrowser(for: .bonjour(type: tableServiceType, domain: nil), using: .tcp)
    private let queue = DispatchQueue(label: "turnkeeper.table.browser")

    public init() {}

    /// Starts browsing; `update` is called with the current tables whenever they change.
    public func start(update: @escaping @Sendable ([TablePeer]) -> Void) {
        browser.browseResultsChangedHandler = { results, _ in
            let peers = results.compactMap { result -> TablePeer? in
                guard case let .service(name, _, _, _) = result.endpoint else { return nil }
                return TablePeer(name: name)
            }
            update(peers.sorted { $0.name < $1.name })
        }
        browser.start(queue: queue)
    }

    public func stop() {
        browser.cancel()
    }
}

/// Follows one sharing device over one connection. When the connection ends, make another to follow again.
public final class TableFollower: @unchecked Sendable {
    public enum Event: Sendable, Equatable {
        case snapshot(TableSnapshot)
        case art(id: String, image: Data)
    }

    private let channel: MessageChannel<TableMessage>
    private let code: String
    private let name: String

    /// - Parameters:
    ///   - code: The code shown on the sharing device.
    ///   - name: This device's name, shown on the sharing device.
    public init(endpoint: NWEndpoint, code: String, name: String) {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        channel = MessageChannel(connection: NWConnection(to: endpoint, using: parameters),
                                 queue: DispatchQueue(label: "turnkeeper.table.follower"))
        self.code = code
        self.name = name
    }

    /// Joins, calls `joined`, then delivers each snapshot and piece of art until the connection ends. Always
    /// throws: `TableError.refused` when the sharing device turned this one away, `connectionLost` otherwise.
    public func follow(joined: @Sendable () async -> Void = {},
                       deliver: @Sendable (Event) async -> Void) async throws -> Never {
        defer { channel.close() }
        do {
            try await channel.open()
            try await channel.send(.join(code: code, name: name))
            try await expectWelcome()
            await joined()
            var newest = 0
            while true {
                switch try await channel.receive() {
                case let .snapshot(snapshot) where snapshot.sequence > newest:
                    newest = snapshot.sequence
                    await deliver(.snapshot(snapshot))
                case let .art(id, image): await deliver(.art(id: id, image: image))
                default: break
                }
            }
        } catch let error as TableError {
            throw error
        } catch {
            throw TableError.connectionLost((error as? NearbyError).map(Self.reason) ?? "\(error)")
        }
    }

    /// Asks the sharing device for a piece of art, which arrives as an `art` event.
    public func requestArt(_ id: String) async {
        try? await channel.send(.needArt(id: id))
    }

    public func stop() {
        channel.close()
    }

    private func expectWelcome() async throws {
        switch try await channel.receive() {
        case .welcome: return
        case let .refused(reason): throw TableError.refused(reason)
        default: throw TableError.connectionLost("the other device sent something unexpected")
        }
    }

    private static func reason(_ error: NearbyError) -> String {
        if case let .connectionFailed(reason) = error { return reason }
        return "\(error)"
    }
}
