import Foundation
import TablesideShared
import Testing
@testable import TurnkeeperKit

@Suite("How many pawns encounters need")
struct PawnTallyTests {
    private let scenarioID = UUID()
    private let goblinPawn = UUID()
    private let ogrePawn = UUID()
    private let base = "Base"
    private let harder = "Harder"

    /// The creatures' pawns: two goblins share one, the ooze has none, and the ghost is gone from the library.
    private func pawn(_ key: String) -> CreaturePawn? {
        switch key {
        case "goblin-warrior": CreaturePawn(name: "Goblin Warrior", pawnID: goblinPawn)
        case "goblin-commando": CreaturePawn(name: "Goblin Commando", pawnID: goblinPawn)
        case "ogre": CreaturePawn(name: "Ogre Warrior", pawnID: ogrePawn)
        case "ooze": CreaturePawn(name: "Sewer Ooze")
        case "trap": CreaturePawn(name: "Spike Trap")
        default: nil
        }
    }

    private func slot(
        _ key: String, _ count: Int = 1, change: (inout EncounterSlot) -> Void = { _ in }
    ) -> EncounterSlot {
        var slot = EncounterSlot(creatureKey: key)
        slot.count = count
        change(&slot)
        return slot
    }

    private func encounter(_ name: String, _ slots: [String: [EncounterSlot]]) -> Encounter {
        var encounter = Encounter(scenarioID: scenarioID, name: name)
        for (label, slots) in slots {
            var variant = EncounterVariant(label: label)
            variant.slots = slots
            encounter.setVariant(variant)
        }
        return encounter
    }

    private func lines(_ encounters: [Encounter], labels: [String]? = nil) -> [PawnSheetRequest.Line] {
        PawnTally(encounters: encounters, labels: labels ?? [base])
            .request(titled: "Trouble in Otari", pawn: pawn).lines
    }

    @Test("One encounter needs as many pawns as it has of each creature")
    func oneEncounter() {
        let docks = encounter("Docks", [base: [slot("goblin-warrior", 3), slot("ogre")]])
        #expect(lines([docks]) == [.init(name: "Goblin Warrior", count: 3, pawnID: goblinPawn),
                                   .init(name: "Ogre Warrior", count: 1, pawnID: ogrePawn)])
    }

    @Test("Three encounters with three goblins each need three goblins, not nine")
    func encountersShareTheirPawns() {
        let encounters = ["Docks", "Cellar", "Tower"].map { encounter($0, [base: [slot("goblin-warrior", 3)]]) }
        #expect(lines(encounters).map(\.count) == [3])
    }

    @Test("A scenario needs the most of each creature that any one encounter has")
    func theLargestCountWins() {
        let docks = encounter("Docks", [base: [slot("goblin-warrior", 2), slot("ogre", 2)]])
        let cellar = encounter("Cellar", [base: [slot("goblin-warrior", 4)]])
        let tower = encounter("Tower", [base: [slot("ogre", 1), slot("goblin-warrior", 1)]])
        #expect(lines([docks, cellar, tower]) == [.init(name: "Goblin Warrior", count: 4, pawnID: goblinPawn),
                                                  .init(name: "Ogre Warrior", count: 2, pawnID: ogrePawn)])
    }

    @Test("Slots of the same creature in one encounter add up, whatever their template, side or place")
    func slotsOfOneFightAddUp() {
        let docks = encounter("Docks", [base: [
            slot("goblin-warrior", 2),
            slot("goblin-warrior") { $0.template = .elite },
            slot("goblin-warrior") { $0.side = .ally },
            slot("goblin-warrior", 2) { $0.startsOnBench = true }
        ]])
        #expect(lines([docks]).map(\.count) == [6])
    }

    @Test("Two creatures with the same pawn share it, under the first one's name")
    func creaturesSharingAPawn() {
        let docks = encounter("Docks", [base: [slot("goblin-warrior", 2), slot("goblin-commando", 1)]])
        let cellar = encounter("Cellar", [base: [slot("goblin-commando", 2)]])
        #expect(lines([docks, cellar]) == [.init(name: "Goblin Warrior", count: 3, pawnID: goblinPawn)])
    }

    @Test("Creatures without a pawn are sent by name, each on its own line")
    func creaturesWithoutAPawn() {
        let docks = encounter("Docks", [base: [slot("ooze", 2), slot("trap"), slot("ooze")]])
        let cellar = encounter("Cellar", [base: [slot("trap", 2)]])
        #expect(lines([docks, cellar]) == [.init(name: "Sewer Ooze", count: 3), .init(name: "Spike Trap", count: 2)])
    }

    @Test("All difficulties take the most any difficulty needs")
    func allDifficulties() {
        let docks = encounter("Docks", [base: [slot("goblin-warrior", 2)],
                                        harder: [slot("goblin-warrior", 4), slot("ogre")]])
        let cellar = encounter("Cellar", [base: [slot("ogre", 2)], harder: [slot("ooze")]])
        let all = lines([docks, cellar], labels: [base, harder])
        #expect(all == [.init(name: "Goblin Warrior", count: 4, pawnID: goblinPawn),
                        .init(name: "Ogre Warrior", count: 2, pawnID: ogrePawn), .init(name: "Sewer Ooze", count: 1)])
    }

    @Test("One difficulty counts only its own creatures")
    func oneDifficulty() {
        let docks = encounter("Docks", [base: [slot("goblin-warrior", 2)], harder: [slot("ogre", 3)]])
        #expect(lines([docks], labels: [harder]) == [.init(name: "Ogre Warrior", count: 3, pawnID: ogrePawn)])
        #expect(lines([docks], labels: ["Easier"]).isEmpty)
    }

    @Test("A creature that is gone and a slot of none are left out")
    func leavesOutWhatCannotBePrinted() {
        let docks = encounter("Docks", [base: [slot("ghost", 2), slot("ogre", 0), slot("goblin-warrior", -1),
                                               slot("trap")]])
        #expect(lines([docks]) == [.init(name: "Spike Trap", count: 1)])
    }

    @Test("Pawns keep the order the encounters plan them in")
    func keepsTheOrder() {
        let docks = encounter("Docks", [base: [slot("trap"), slot("ogre")]])
        let cellar = encounter("Cellar", [base: [slot("goblin-warrior"), slot("ogre", 2), slot("ooze")]])
        #expect(lines([docks, cellar]).map(\.name) == ["Spike Trap", "Ogre Warrior", "Goblin Warrior", "Sewer Ooze"])
    }

    @Test("The request carries the sheet's title")
    func carriesTheTitle() {
        let request = PawnTally(encounters: [], labels: [base]).request(titled: "Trouble in Otari", pawn: pawn)
        #expect(request == PawnSheetRequest(title: "Trouble in Otari", lines: []))
    }

    @Test("It says whether anything is planned")
    func saysWhetherAnythingIsPlanned() {
        let empty = encounter("Docks", [base: []])
        let none = encounter("Cellar", [base: [slot("ogre", 0)]])
        let planned = encounter("Tower", [harder: [slot("ogre")]])
        #expect(!PawnTally(encounters: [empty, none], labels: [base, harder]).hasCreatures)
        #expect(!PawnTally(encounters: [planned], labels: [base]).hasCreatures)
        #expect(PawnTally(encounters: [empty, planned], labels: [base, harder]).hasCreatures)
        #expect(!PawnTally(encounters: [], labels: [base]).hasCreatures)
    }
}
