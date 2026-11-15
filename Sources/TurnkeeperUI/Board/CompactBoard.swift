import BattleCards
import TurnkeeperKit
import SwiftUI

/// The top bar where the board shows the ladder alone, as on an iPhone: closing, the fight's name and turn, the
/// player screen and one menu for the rest, then the turn buttons when they have no bar of their own. Duration
/// arrows get a row of their own.
struct CompactTopBar<TurnButtons: View>: View {
    let controller: BoardController
    @Binding var sheet: BoardSheet?
    @ViewBuilder let turnButtons: () -> TurnButtons
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                Button("Close", systemImage: "xmark") { model.closeBoard() }
                    .labelStyle(.iconOnly)
                VStack(alignment: .leading, spacing: 0) {
                    Text(controller.session?.name ?? "").font(.headline)
                    Text(turnText).font(.caption).foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                PlayerScreenToggle()
                    .labelStyle(.iconOnly)
                FightMenu(controller: controller) {
                    AddToFightButtons(controller: controller, sheet: $sheet)
                    Divider()
                }
                .labelStyle(.iconOnly)
                turnButtons().frame(maxWidth: 360)
            }
            if !controller.state.durations.isEmpty {
                DurationArrows(controller: controller, maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var turnText: String {
        controller.state.phase == .setup ? "Setup · enter everyone's initiative" : controller.turnText
    }
}

/// The turn buttons where the board shows the ladder alone: Begin Combat in setup, then Undo, the acting
/// combatant's card and a wide Next.
struct CompactTurnButtons: View {
    let controller: BoardController
    @Binding var sheet: BoardSheet?

    var body: some View {
        HStack(spacing: 12) {
            if controller.state.phase == .setup {
                BeginCombatButton(controller: controller)
                    .frame(maxWidth: .infinity)
            } else {
                Button("Undo", systemImage: "arrow.uturn.backward") { controller.undo() }
                    .labelStyle(.iconOnly)
                    .disabled(!controller.canUndo)
                Button("Card", systemImage: "rectangle.portrait") {
                    controller.pinnedID = nil
                    sheet = .card
                }
                .help("Show the battle card of whoever is acting")
                Button { controller.next() } label: {
                    Label("Next", systemImage: "forward.end.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(controller.isBlocked)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
}

/// The battle card and the notes as a sheet over the ladder: the card of the strip that was tapped, or of whoever
/// is acting.
struct CompactCardSheet: View {
    let controller: BoardController
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var page = Page.card

    private enum Page: String, CaseIterable {
        case card = "Card"
        case notes = "Notes"
    }

    var body: some View {
        NavigationStack {
            Group {
                switch page {
                case .card: BoardCard(controller: controller)
                case .notes: notes
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PadBackground())
            .navigationTitle(controller.cardCombatant?.name ?? "")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Show", selection: $page) {
                        ForEach(Page.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .battleCardFullScreenHost()
    }

    private var notes: some View {
        let notes = BoardNotes(controller: controller, model: model)
        return VStack(alignment: .leading, spacing: 8) {
            if notes.hasCreatureNotes {
                pane(notes.titles[SplitLayout.creatureNotes] ?? "", text: notes.creatureNote)
            }
            pane(notes.titles[SplitLayout.encounterNotes] ?? "", text: notes.encounterNotes)
        }
    }

    private func pane(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            NotesEditor(text: text)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
