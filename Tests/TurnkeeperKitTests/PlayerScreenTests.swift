import Bestiary
import Foundation
import Testing
@testable import TurnkeeperKit

@Suite("The player screen's initiative order")
struct PlayerScreenTests {
    /// Every creature has 40 HP; PCs have none on the board.
    private func lines(_ state: CombatState) -> [PlayerScreenLine] {
        state.playerScreen { $0.tracksHitPoints ? 40 : 0 }.lines
    }

    @Test("The ladder in order, the current strip active, delaying strips marked")
    func order() {
        var (state, ids) = fight()
        state.startDelay(ids[2])
        let result = lines(state)
        #expect(result.map(\.id) == ids)
        #expect(result.map(\.isActive) == [true, false, false])
        #expect(result.map(\.isDelaying) == [false, false, true])
        #expect(result.map(\.magnet) == [.red, .blue, .red])
    }

    @Test("Benched combatants are left out")
    func benchHidden() {
        var (state, ids) = fight()
        var wolf = Combatant(kind: .creature, name: "Wolf")
        wolf.place = .bench
        state.combatants.append(wolf)
        #expect(lines(state).map(\.id) == ids)
    }

    @Test("Enemies show a health estimate; PCs and allies show none")
    func healthOnlyForEnemies() {
        var (state, ids) = fight()
        state.applyDamage(25, to: ids[0])
        state[ids[2]]?.side = .ally
        let health = lines(state).map(\.health)
        #expect(health == [.bloodied, nil, nil])
    }

    @Test("Damage moves an enemy through the bands", arguments: [
        (0, HealthEstimate.unharmed), (1, .healthy), (9, .healthy), (10, .injured), (19, .injured),
        (20, .bloodied), (29, .bloodied), (30, .nearDeath), (39, .nearDeath), (40, .down), (55, .down)
    ])
    func bands(damage: Int, expected: HealthEstimate) {
        var (state, ids) = fight()
        state.applyDamage(damage, to: ids[0])
        #expect(lines(state).first?.health == expected)
    }

    @Test("A dying enemy is down whatever its HP")
    func dyingIsDown() {
        var (state, ids) = fight()
        state.knockOut(ids[0])
        #expect(lines(state).first { $0.id == ids[0] }?.health == .down)
    }

    @Test("A stabilized enemy is still down while unconscious")
    func unconsciousIsDown() {
        var (state, ids) = fight()
        state.knockOut(ids[0])
        state.stabilize(ids[0])
        #expect(lines(state).first { $0.id == ids[0] }?.health == .down)
    }

    @Test("A dead strip is marked dead, and a dead enemy is down whatever its HP")
    func deadIsDown() {
        var (state, ids) = fight()
        state.markDead(ids[0])
        let result = lines(state)
        #expect(result.map(\.isDead) == [true, false, false])
        #expect(result.first?.health == .down)
    }

    @Test("A dead strip is sent to following devices, and an older host's strips aren't dead")
    func deadIsShared() throws {
        var (state, ids) = fight()
        state.markDead(ids[0])
        let sent = try JSONEncoder().encode(lines(state).map { TableLine($0, card: nil) })
        let received = try JSONDecoder().decode([TableLine].self, from: sent)
        #expect(received.map(\.playerLine.isDead) == [true, false, false])
        var older = try #require(JSONSerialization.jsonObject(with: sent) as? [[String: Any]])
        older[0]["isDead"] = nil
        let decoded = try JSONDecoder().decode([TableLine].self, from: JSONSerialization.data(withJSONObject: older))
        #expect(decoded.map(\.playerLine.isDead) == [false, false, false])
    }

    @Test("An enemy without a known maximum shows no estimate")
    func unknownMaximum() {
        let (state, _) = fight()
        #expect(state.playerScreen { _ in 0 }.lines.allSatisfy { $0.health == nil })
    }

    @Test("Before combat begins, nobody is active and there's no art")
    func setupHasNoActiveStrip() {
        let state = CombatState(combatants: [Combatant(kind: .creature, name: "Goblin", creatureKey: "goblin")])
        #expect(lines(state).map(\.isActive) == [false])
        #expect(state.playerScreen { _ in 0 }.activeKey.isEmpty)
    }

    @Test("The art is the acting combatant's")
    func activeArt() {
        var (state, ids) = fight()
        state[ids[0]]?.creatureKey = "goblin-warrior"
        #expect(state.playerScreen { _ in 0 }.activeKey == "goblin-warrior")
    }
}
