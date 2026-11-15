import Bestiary
import Foundation
import Testing
@testable import TurnkeeperKit

@Suite("Dead strips")
struct DeathTests {
    /// Passes the turn `count` times, gathering the reminder titles.
    private func advance(_ state: inout CombatState, times count: Int = 1) -> [String] {
        var titles: [String] = []
        for _ in 0..<count {
            let advance = TurnAdvancer.next(state)
            titles += advance.reminders.map(\.title)
            state = advance.state
        }
        return titles
    }

    @Test("A dead strip keeps its place and its turn is skipped")
    func skipped() {
        var (state, ids) = fight()
        state.markDead(ids[1])
        #expect(advance(&state).isEmpty)
        #expect(state.order == ids)
        #expect(state.currentID == ids[2])
    }

    @Test("A dead strip raises no reminders, and its conditions don't change")
    func noReminders() {
        let slot = UUID()
        var (state, ids) = fight(events: [EncounterEvent(label: "Rage", trigger: .turnStart(slotID: slot))])
        state[ids[1]]?.slotID = slot
        state.addCondition(AppliedCondition(slug: "dying", value: 1), to: ids[1])
        state.addCondition(AppliedCondition(slug: "frightened", value: 2), to: ids[1])
        state.markDead(ids[1])
        #expect(advance(&state, times: 6).isEmpty)
        #expect(state[ids[1]]?.condition("frightened")?.value == 2)
    }

    @Test("A strip that dies on its own turn has no end-of-turn reminders")
    func diesOnItsTurn() {
        var (state, ids) = fight()
        state.addCondition(AppliedCondition(slug: "frightened", value: 1), to: ids[0])
        state.markDead(ids[0])
        #expect(state.currentID == ids[0])
        #expect(advance(&state).isEmpty)
        #expect(state.currentID == ids[1])
    }

    @Test("A round starts with the first strip that isn't dead")
    func roundStart() {
        var (state, ids) = fight()
        state.markDead(ids[0])
        _ = advance(&state, times: 3)
        #expect(state.round == 2)
        #expect(state.currentID == ids[1])
    }

    @Test("Duration arrows anchored to a dead strip still count down", arguments: [TurnMoment.startOfTurn, .endOfTurn])
    func durations(moment: TurnMoment) {
        var (state, ids) = fight()
        state.addDuration(DurationMarker(label: "Fear", rounds: 2, anchor: ids[1], moment: moment))
        state.markDead(ids[1])
        #expect(advance(&state, times: 2).isEmpty)
        #expect(advance(&state, times: 3) == ["Fear ends"])
        #expect(state.durations.isEmpty)
    }

    @Test("A duration ending at the end of the turn its anchor died on still counts down")
    func durationOnFinalTurn() {
        var (state, ids) = fight()
        state.addDuration(DurationMarker(label: "Shield", rounds: 1, anchor: ids[0], moment: .endOfTurn))
        state.markDead(ids[0])
        #expect(advance(&state) == ["Shield ends"])
    }

    @Test("Delaying strips beyond a dead one are still offered a turn, and wait below the next living strip")
    func delayedBeyondDead() {
        var (state, ids) = fight(withWolf: true)
        state.markDead(ids[1])
        state[ids[2]]?.isDelaying = true
        #expect(state.delayedStripsAhead.map(\.id) == [ids[2]])
        let waiting = TurnAdvancer.next(state).state
        #expect(waiting.currentID == ids[3])
        #expect(waiting.order == [ids[0], ids[1], ids[3], ids[2]])
        #expect(TurnAdvancer.next(state, actingNow: [ids[2]]).state.currentID == ids[2])
    }

    @Test("Dying ends a delay, and a dead strip can't delay")
    func noDelay() {
        var (state, ids) = fight()
        state.startDelay(ids[2])
        state.markDead(ids[2])
        #expect(state[ids[2]]?.isDelaying == false)
        state.startDelay(ids[2])
        #expect(state.delaying.isEmpty)
    }

    @Test("A revived strip takes its turns again")
    func revive() {
        var (state, ids) = fight()
        state.markDead(ids[1])
        state.revive(ids[1])
        _ = advance(&state)
        #expect(state.currentID == ids[1])
    }

    @Test("Knocking out a dead strip makes it dying, not dead")
    func knockedOutInstead() {
        var (state, ids) = fight()
        state.markDead(ids[2])
        state.knockOut(ids[2])
        #expect(state[ids[2]]?.isDead == false)
        #expect(state[ids[2]]?.isDying == true)
    }

    @Test("With everyone else dead, the last strip keeps taking turns")
    func lastStanding() {
        var (state, ids) = fight()
        state.markDead(ids[0])
        state.markDead(ids[2])
        _ = advance(&state, times: 2)
        #expect(state.currentID == ids[1])
        #expect(state.round == 2)
    }

    @Test("When the only living strip is delaying, the round starts with it")
    func delayingSurvivor() {
        var (state, ids) = fight()
        state.markDead(ids[0])
        state.markDead(ids[1])
        state[ids[2]]?.isDelaying = true
        #expect(state.firstOfRound == ids[2])
    }

    @Test("A ladder of the dead passes turns without reminders")
    func everyoneDead() {
        var (state, ids) = fight()
        ids.forEach { state.markDead($0) }
        #expect(advance(&state, times: 2).isEmpty)
        #expect(state.currentID == ids[0])
        #expect(CombatState().firstOfRound == nil)
    }

    @Test("Every enemy dead counts as all enemies down, whatever their HP")
    func allEnemiesDown() {
        var (state, ids) = fight()
        state.markDead(ids[0])
        #expect(!state.allEnemiesDown { _ in 30 })
        state.markDead(ids[2])
        #expect(state.allEnemiesDown { _ in 30 })
    }

    @Test("A session saved before the Dead status decodes with nobody dead")
    func oldSessionDecodes() throws {
        let (state, _) = fight()
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        let combatants = try #require(json["combatants"] as? [[String: Any]])
        json["combatants"] = combatants.map { $0.filter { $0.key != "isDead" } }
        let decoded = try JSONDecoder().decode(CombatState.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded == state)
    }
}

@Suite("Dying at 0 HP")
struct SettleDeathsTests {
    /// Every creature has 20 HP; PCs have none on the board.
    private func settle(_ state: inout CombatState, _ edit: (inout CombatState) -> Void) {
        let previous = state
        edit(&state)
        state.settleDeaths(since: previous) { $0.tracksHitPoints ? 20 : 0 }
    }

    @Test("Damage that brings a creature to 0 HP kills it; less doesn't")
    func damage() {
        var (state, ids) = fight()
        settle(&state) { $0.applyDamage(19, to: ids[0]) }
        #expect(state[ids[0]]?.isDead == false)
        settle(&state) { $0.applyDamage(5, to: ids[0]) }
        #expect(state[ids[0]]?.isDead == true)
    }

    @Test("Healing a dead creature above 0 HP revives it")
    func healing() {
        var (state, ids) = fight()
        settle(&state) { $0.applyDamage(20, to: ids[0]) }
        settle(&state) { $0.heal(1, on: ids[0]) }
        #expect(state[ids[0]]?.isDead == false)
    }

    @Test("A creature the GM revived at 0 HP stays alive through other changes")
    func revivedStays() {
        var (state, ids) = fight()
        settle(&state) { $0.applyDamage(20, to: ids[0]) }
        settle(&state) { $0.revive(ids[0]) }
        settle(&state) { $0.applyDamage(3, to: ids[0]) }
        #expect(state[ids[0]]?.isDead == false)
    }

    @Test("A creature marked dead with HP left stays dead when it takes more damage")
    func markedStays() {
        var (state, ids) = fight()
        settle(&state) { $0.markDead(ids[0]) }
        settle(&state) { $0.applyDamage(3, to: ids[0]) }
        #expect(state[ids[0]]?.isDead == true)
    }

    @Test("A creature knocked out as it drops is dying, not dead")
    func knockedOut() {
        var (state, ids) = fight()
        settle(&state) { state in
            state.applyDamage(20, to: ids[0])
            state.knockOut(ids[0])
        }
        #expect(state[ids[0]]?.isDead == false)
    }

    @Test("PCs, creatures without a known maximum, and newcomers are left alone")
    func leftAlone() {
        var (state, ids) = fight()
        settle(&state) { $0[ids[1]]?.damageTaken = 99 }
        #expect(state[ids[1]]?.isDead == false)
        let previous = state
        state.applyDamage(99, to: ids[0])
        state.settleDeaths(since: previous) { _ in 0 }
        state.settleDeaths(since: CombatState()) { _ in 20 }
        #expect(state[ids[0]]?.isDead == false)
    }
}
