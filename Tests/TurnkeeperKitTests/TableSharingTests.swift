import Bestiary
import Foundation
import Network
import Testing
@testable import TurnkeeperKit

@Suite("Sharing the player screen")
struct TableSharingTests {
    private func line(_ name: String, key: String = "", isActive: Bool = false) -> PlayerScreenLine {
        PlayerScreenLine(id: UUID(), name: name, magnet: .red, isActive: isActive, isDelaying: false,
                         health: .bloodied, creatureKey: key)
    }

    private func fight(_ names: String...) -> TableSnapshot.Content {
        .fight(names.map { TableLine(line($0), card: nil) })
    }

    /// The names on a snapshot's strips: each `fight` makes strips with IDs of their own.
    private func stripNames(_ snapshot: TableSnapshot?) -> [String] {
        guard case let .fight(lines) = snapshot?.content else { return [] }
        return lines.map(\.name)
    }

    private func host(code: String = "4321", art: [String: Data] = [:], names: Names = Names()) throws -> TableHost {
        try TableHost(name: nil, code: code, art: { art[$0] }, followersChanged: { names.set($0) })
    }

    private func follower(_ port: NWEndpoint.Port, code: String = "4321", name: String = "Phone") -> TableFollower {
        TableFollower(endpoint: .hostPort(host: "127.0.0.1", port: port), code: code, name: name)
    }

    /// Follows in the background and collects what arrives.
    private func start(_ follower: TableFollower) -> (Events, Task<TableError?, Never>) {
        let events = Events()
        let task = Task { () -> TableError? in
            do {
                try await follower.follow { await events.add($0) }
            } catch {
                return error as? TableError
            }
        }
        return (events, task)
    }

    @Test("A strip is sent with what the player screen shows, and comes back the same")
    func lineRoundTrip() throws {
        let original = line("Goblin Warrior 1", key: "goblin-warrior", isActive: true)
        let card = TableCard(name: "Goblin Warrior", game: .pathfinder, traits: ["goblin"], artID: "library:7")
        let sent = TableLine(original, card: card)
        let received = try JSONDecoder().decode(TableLine.self, from: JSONEncoder().encode(sent))
        #expect(received.card == card)
        #expect(received.playerLine.health == .bloodied)
        #expect(received.playerLine.isActive)
        // The creature key stays on the sharing device.
        #expect(received.playerLine.creatureKey.isEmpty)
        let json = String(bytes: try JSONEncoder().encode(sent), encoding: .utf8) ?? ""
        #expect(!json.isEmpty && !json.contains("goblin-warrior"))
    }

    @Test("A fight's strips get a card back only when they have a creature")
    func fightContent() {
        let lines = [line("Wolf", key: "wolf", isActive: true), line("Kyra")]
        let content = TableSnapshot.Content.fight(PlayerScreenFight(lines: lines, activeKey: "wolf")) { key in
            TableCard(name: key.capitalized, game: .pathfinder, traits: [], artID: "art:\(key)")
        }
        guard case let .fight(sent) = content else {
            Issue.record("Expected a fight")
            return
        }
        #expect(sent.map(\.card?.artID) == ["art:wolf", nil])
        #expect(content.activeLine?.name == "Wolf")
        #expect(TableSnapshot.Content.waiting.activeLine == nil)
    }

    @Test("Reconnecting starts at once and backs off to five seconds", arguments: [
        (1, 0.5), (2, 1.0), (3, 2.0), (4, 4.0), (5, 5.0), (40, 5.0), (0, 0.5)
    ])
    func reconnectDelay(failures: Int, seconds: Double) {
        #expect(ReconnectDelay.seconds(afterFailures: failures) == seconds)
    }

    @Test("A follower gets the current snapshot on joining, then each one published")
    func follows() async throws {
        let names = Names()
        let host = try host(names: names)
        let port = try await host.start()
        defer { host.stop() }
        await host.publish(fight("Wolf"))
        let follower = follower(port)
        let (events, task) = start(follower)
        #expect(stripNames(await events.waitForSnapshots(1).last) == ["Wolf"])
        await host.publish(fight("Wolf", "Kyra"))
        #expect(stripNames(await events.waitForSnapshots(2).last) == ["Wolf", "Kyra"])
        #expect(names.value == ["Phone"])
        follower.stop()
        #expect(await task.value != nil)
    }

    @Test("Several devices follow at once, and one that comes back gets the current snapshot")
    func severalFollowersAndReturning() async throws {
        let host = try host()
        let port = try await host.start()
        defer { host.stop() }
        let first = follower(port, name: "One")
        let second = follower(port, name: "Two")
        let (firstEvents, _) = start(first)
        let (secondEvents, _) = start(second)
        await host.publish(fight("Wolf"))
        #expect(await firstEvents.waitForSnapshots(1).count == 1)
        #expect(await secondEvents.waitForSnapshots(1).count == 1)

        // The first device goes to another app, missing a turn, and comes back with a new connection.
        first.stop()
        await host.publish(fight("Kyra"))
        let back = follower(port, name: "One")
        let (backEvents, _) = start(back)
        #expect(stripNames(await backEvents.waitForSnapshots(1).last) == ["Kyra"])
        #expect(stripNames(await secondEvents.waitForSnapshots(2).last) == ["Kyra"])
        back.stop()
        second.stop()
    }

    @Test("Art on show is sent when a follower asks for it; anything else comes back empty")
    func art() async throws {
        let host = try host(art: ["library:7": Data([1, 2, 3]), "../library.json": Data([9])])
        let port = try await host.start()
        defer { host.stop() }
        let follower = follower(port)
        let (events, _) = start(follower)
        let card = TableCard(name: "Wolf", game: .pathfinder, traits: [], artID: "library:7")
        let noArt = TableCard(name: "Bat", game: .pathfinder, traits: [], artID: "library:8")
        await host.publish(.fight([TableLine(line("Wolf"), card: card), TableLine(line("Bat"), card: noArt)]))
        _ = await events.waitForSnapshots(1)
        await follower.requestArt("library:7")
        // On show, but the sharing device has no picture for it.
        await follower.requestArt("library:8")
        // Not on show: a file the follower has no business with.
        await follower.requestArt("../library.json")
        let art = await events.waitForArt(3)
        #expect(art == [.art(id: "library:7", image: Data([1, 2, 3])), .art(id: "library:8", image: Data()),
                        .art(id: "../library.json", image: Data())])
        follower.stop()
    }

    @Test("The art that can be asked for is the card backs' and the handout's")
    func artOnShow() {
        let card = TableCard(name: "Wolf", game: .pathfinder, traits: [], artID: "library:7")
        let plain = TableCard(name: "Kyra", game: .pathfinder, traits: [], artID: "")
        let lines = [TableLine(line("Wolf"), card: card), TableLine(line("Kyra"), card: plain),
                     TableLine(line("Ezren"), card: nil)]
        let fight = TableSnapshot.Content.fight(lines)
        #expect(fight.artIDs == ["library:7"])
        #expect(TableSnapshot.Content.handout(name: "Map", artID: "Pasted/map.jpg").artIDs == ["Pasted/map.jpg"])
        #expect(TableSnapshot.Content.handout(name: "Map", artID: "").artIDs.isEmpty)
        #expect(TableSnapshot.Content.waiting.artIDs.isEmpty)
    }

    @Test("A wrong code is refused, and the device isn't counted as following")
    func wrongCode() async throws {
        let names = Names()
        let host = try host(names: names)
        let port = try await host.start()
        defer { host.stop() }
        let (_, task) = start(follower(port, code: "0000"))
        guard case .refused = await task.value else {
            Issue.record("Expected a refusal")
            return
        }
        #expect(names.value.isEmpty)
    }

    @Test("Stopping the sharing device ends the follower's connection as lost, not refused")
    func hostStops() async throws {
        let host = try host()
        let port = try await host.start()
        let (events, task) = start(follower(port))
        await host.publish(.waiting)
        _ = await events.waitForSnapshots(1)
        host.stop()
        guard case .connectionLost = await task.value else {
            Issue.record("Expected a lost connection")
            return
        }
    }

    @Test("A follower can't send the sharing device more than a request's worth")
    func incomingLimit() {
        var buffer = Data([0x00, 0x02, 0x00, 0x00])
        #expect(throws: NearbyError.self) {
            try NearbyFraming.next(TableMessage.self, from: &buffer, limit: TableHost.incomingLimit)
        }
    }

    @Test("Errors say what failed")
    func errors() {
        #expect(TableError.refused("the code doesn't match.").errorDescription?.hasPrefix("Joining failed") == true)
        #expect(TableError.connectionLost("reset").errorDescription?.contains("reset") == true)
        #expect(TablePeer(name: "GM's iPad").id == "GM's iPad")
    }
}

/// What a follower was sent, in order.
private actor Events {
    private var events: [TableFollower.Event] = []

    func add(_ event: TableFollower.Event) {
        events.append(event)
    }

    private var snapshots: [TableSnapshot] {
        events.compactMap { if case let .snapshot(snapshot) = $0 { snapshot } else { nil } }
    }

    private var art: [TableFollower.Event] {
        events.filter { if case .art = $0 { true } else { false } }
    }

    /// The snapshots so far, once there are `count` of them (or after five seconds).
    func waitForSnapshots(_ count: Int) async -> [TableSnapshot] {
        for _ in 0..<250 where snapshots.count < count { try? await Task.sleep(for: .milliseconds(20)) }
        return snapshots
    }

    func waitForArt(_ count: Int) async -> [TableFollower.Event] {
        for _ in 0..<250 where art.count < count { try? await Task.sleep(for: .milliseconds(20)) }
        return art
    }
}

/// The followers' names, as the sharing device last reported them.
private final class Names: @unchecked Sendable {
    private let lock = NSLock()
    private var names: [String] = []

    var value: [String] { lock.withLock { names } }

    func set(_ names: [String]) {
        lock.withLock { self.names = names }
    }
}
