import Bestiary
import TurnkeeperKit
import SwiftUI

/// The sheet for a board action.
struct BoardSheetContent: View {
    let sheet: BoardSheet
    let controller: BoardController

    var body: some View {
        switch sheet {
        case let .hitPoints(id): HitPointsPad(controller: controller, id: id)
        case let .initiative(id): InitiativePad(controller: controller, id: id)
        case let .conditions(id): ConditionPalette(controller: controller, id: id)
        case let .rename(id): RenameStripSheet(controller: controller, id: id)
        case .duration: DurationEditor(controller: controller)
        case .card: CompactCardSheet(controller: controller)
        case .creature: AddCreatureSheet(controller: controller)
        case .voiceInitiative: VoiceInitiativeScreen(controller: controller)
        case .event:
            EventEditor(event: EncounterEvent(label: "", trigger: .initiative(20)), slots: []) { event in
                controller.change { $0.addEvent(event) }
            }
        }
    }
}

/// The bestiary on the board, to add creatures the plan left out: enemies, or allies such as reinforcements.
private struct AddCreatureSheet: View {
    let controller: BoardController
    @Environment(AppModel.self) private var model
    @State private var side = Side.enemy

    var body: some View {
        let partyLevel = model.party(controller.session?.partyID)?.level
        BestiaryBrowser(game: model.game, partyLevel: partyLevel, add: { key in
            controller.addCreature(key, side: side)
        }, joiningSide: $side)
    }
}

/// Adds a duration arrow: a label, how many rounds, and whose turn it counts down on.
private struct DurationEditor: View {
    let controller: BoardController
    @Environment(\.dismiss) private var dismiss
    @State private var label = ""
    @State private var rounds = 1
    @State private var anchor: UUID?
    @State private var moment = TurnMoment.startOfTurn

    var body: some View {
        NavigationStack {
            Form {
                TextField("Label", text: $label, prompt: Text("Bless"))
                Stepper("\(rounds) round\(rounds == 1 ? "" : "s")", value: $rounds, in: 1...100)
                Picker("Counts down on", selection: $anchor) {
                    ForEach(controller.state.ladder) { Text($0.name).tag(UUID?.some($0.id)) }
                }
                Picker("At", selection: $moment) {
                    Text("Start of turn").tag(TurnMoment.startOfTurn)
                    Text("End of turn").tag(TurnMoment.endOfTurn)
                }
                .pickerStyle(.segmented)
            }
            .formStyle(.grouped)
            .navigationTitle("Duration Arrow")
            .onAppear { anchor = controller.state.currentID ?? controller.state.order.first }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let anchor {
                            let marker = DurationMarker(label: label.isEmpty ? "Effect" : label, rounds: rounds,
                                                        anchor: anchor, moment: moment)
                            controller.change { $0.addDuration(marker) }
                        }
                        dismiss()
                    }
                }
            }
        }
        .sheetFrame(minWidth: 400, minHeight: 320)
    }
}

/// Renames a strip for this fight, such as "Goblin Archer" for "Goblin 2"; the plan and the party keep their names.
private struct RenameStripSheet: View {
    let controller: BoardController
    let id: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @FocusState private var isEditing: Bool

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                    .nameEntry()
                    .focused($isEditing)
                    .onSubmit(rename)
            }
            .formStyle(.grouped)
            .navigationTitle("Rename")
            .onAppear {
                name = controller.state[id]?.name ?? ""
                isEditing = true
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Rename", action: rename)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .sheetFrame(minWidth: 360, minHeight: 160)
    }

    private func rename() {
        controller.change { $0.rename(id, to: name) }
        dismiss()
    }
}
