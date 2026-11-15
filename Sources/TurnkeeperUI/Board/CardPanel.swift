import BattleCards
import Bestiary
import TurnkeeperKit
import SwiftUI

/// The notes half of the board: the battle card of whoever's turn it is (or the pinned combatant), then the
/// notes about that creature in this scenario and the encounter's notes, in a split the GM can resize.
struct CardPanel: View {
    let controller: BoardController
    @Environment(AppModel.self) private var model
    private var layout = StoredSplitLayout()

    init(controller: BoardController) {
        self.controller = controller
    }

    var body: some View {
        let notes = BoardNotes(controller: controller, model: model)
        VStack(spacing: 10) {
            header
            PaneStack(layout: layout.projectedValue, visible: visiblePanes(notes), titles: notes.titles) {
                BoardCard(controller: controller)
            } creatureNotes: {
                NotesEditor(text: notes.creatureNote)
            } encounterNotes: {
                NotesEditor(text: notes.encounterNotes)
            }
        }
        .padding(12)
    }

    private func visiblePanes(_ notes: BoardNotes) -> Set<Int> {
        notes.hasCreatureNotes ? SplitLayout.allPanes : [SplitLayout.card, SplitLayout.encounterNotes]
    }

    @ViewBuilder
    private var header: some View {
        if controller.pinnedID != nil {
            Button("Current Turn", systemImage: "arrow.uturn.backward") { controller.pinnedID = nil }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// The notes beside the board's card: the shown creature's note in this scenario, and the encounter's notes.
@MainActor
struct BoardNotes {
    let controller: BoardController
    let model: AppModel

    /// Creature notes show for creatures and hazards, not PCs.
    var hasCreatureNotes: Bool {
        let isCreature = controller.cardCombatant.map { !$0.creatureKey.isEmpty && $0.kind != .playerCharacter }
        return (isCreature ?? false) && scenarioID != nil
    }

    var titles: [Int: String] {
        let name = controller.cardCombatant.flatMap { controller.entry(for: $0)?.name } ?? ""
        return [SplitLayout.creatureNotes: "Creature Notes · \(name)", SplitLayout.encounterNotes: "Encounter Notes"]
    }

    var creatureNote: Binding<String> {
        let subject = controller.cardCombatant?.creatureKey ?? ""
        return Binding { [model, scenarioID] in
            scenarioID.map { model.library.creatureNote(scenarioID: $0, subject: subject).text } ?? ""
        } set: { [model, scenarioID] text in
            guard let scenarioID else { return }
            var note = model.library.creatureNote(scenarioID: scenarioID, subject: subject)
            note.text = text
            model.library.save(note)
        }
    }

    var encounterNotes: Binding<String> {
        Binding { [encounter] in encounter?.notes ?? "" } set: { [model, encounter] text in
            guard var edited = encounter.flatMap({ model.encounter($0.id) }) else { return }
            edited.notes = text
            model.library.save(edited)
        }
    }

    private var encounter: Encounter? { controller.session.flatMap { model.encounter($0.encounterID) } }
    private var scenarioID: UUID? { encounter?.scenarioID }
}

/// The battle card of the pinned strip, or of whoever is acting.
struct BoardCard: View {
    let controller: BoardController

    var body: some View {
        if let combatant = controller.cardCombatant {
            card(for: combatant)
        } else {
            ContentUnavailableView("No one is acting", systemImage: "rectangle.portrait",
                                   description: Text("Begin combat, or tap a strip to see its card."))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func card(for combatant: Combatant) -> some View {
        if let creature = controller.creature(for: combatant) {
            VStack(spacing: 6) {
                // A new turn, or another strip tapped, shows the stat block again.
                CreatureBattleCard(entry: controller.entry(for: combatant), front: BattleCard(
                    creature: creature, template: combatant.template, conditions: combatant.conditions))
                    .id(combatant.id)
                MissingArtNote(key: combatant.creatureKey).foregroundStyle(.white.opacity(0.7))
            }
        } else {
            PlayerCard(combatant: combatant)
        }
    }
}

/// For quick PCs, without a linked sheet: the name and each condition's rules text.
private struct PlayerCard: View {
    let combatant: Combatant
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(combatant.name).font(.largeTitle.bold())
                if combatant.conditions.isEmpty {
                    Text("No conditions.").foregroundStyle(.secondary)
                }
                ForEach(combatant.conditions) { condition in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ConditionLabel.short(condition)).font(.headline)
                        if let definition = model.bestiary.condition(condition.slug) {
                            Text(plainText(definition.text)).font(.callout)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func plainText(_ text: RulesText) -> String {
        StatBlockText.plainText(text).replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "\n---", with: "")
    }
}

/// A notes text area on the board, saved as it's typed.
struct NotesEditor: View {
    @Binding var text: String

    var body: some View {
        TextEditor(text: $text)
            .font(.callout)
            .scrollContentBackground(.hidden)
            .background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
    }
}
