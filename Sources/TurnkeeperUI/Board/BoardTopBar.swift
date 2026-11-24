import TurnkeeperKit
import SwiftUI

/// Sheets the board opens.
enum BoardSheet: Identifiable, Hashable {
    case hitPoints(UUID)
    case initiative(UUID)
    case conditions(UUID)
    case rename(UUID)
    case duration
    case event
    /// The bestiary, to add a creature the plan left out.
    case creature
    /// The battle card of the pinned strip, or of whoever is acting: a sheet where the board shows the ladder alone.
    case card
    /// Setup's voice initiative screen, which listens while it's open.
    case voiceInitiative

    var id: String { String(describing: self) }
}

/// Round, turn controls, duration arrows and the encounter's name and difficulty.
struct BoardTopBar: View {
    let controller: BoardController
    @Binding var sheet: BoardSheet?
    @Environment(AppModel.self) private var model
    @Environment(\.boardTheme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            Button("Close", systemImage: "xmark") { model.closeBoard() }
                .labelStyle(.iconOnly)
                .help("Close the board. The fight is kept; Run or Resume brings it back.")
            VStack(alignment: .leading, spacing: 0) {
                Text(controller.session?.name ?? "").font(.headline)
                Text(roundText).font(.caption).foregroundStyle(.secondary)
            }
            // An upright iPad has little room beside the buttons: the name gives way, not their titles.
            .lineLimit(2)
            // Nothing running takes no room: an empty row of arrows squeezed the fight's name.
            if !controller.state.durations.isEmpty { DurationArrows(controller: controller) }
            Spacer()
            PlayerScreenToggle()
                .fixedSize()
            Menu("Add", systemImage: "plus") { AddToFightButtons(controller: controller, sheet: $sheet) }
            if controller.state.phase == .setup {
                BeginCombatButton(controller: controller)
            } else {
                FightMenu(controller: controller)
                Button("Undo", systemImage: "arrow.uturn.backward") { controller.undo() }
                    .disabled(!controller.canUndo)
                Button("Next", systemImage: "forward.end.fill") { controller.next() }
                    .buttonStyle(.borderedProminent)
                    .disabled(controller.isBlocked)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var roundText: String {
        controller.state.phase == .setup
            ? "Roll for initiative: open Voice Initiative below and say the totals, or tap a strip"
            : controller.turnText
    }
}

extension BoardController {
    /// "Round 2 · Kyra's turn".
    var turnText: String {
        "Round \(state.round) · \(state.current?.name ?? "—")'s turn"
    }
}

/// The colored duration arrows: what's running and how many rounds are left. Tap one to remove it.
struct DurationArrows: View {
    let controller: BoardController
    var maxWidth: CGFloat = 360

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(controller.state.durations) { marker in
                    Button {
                        controller.change { $0.durations.removeAll { $0.id == marker.id } }
                    } label: {
                        Label("\(marker.label) \(marker.roundsRemaining)", systemImage: "arrowtriangle.right.fill")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(color(for: marker).opacity(0.85), in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .help("Ends at the \(marker.moment == .startOfTurn ? "start" : "end") of "
                          + "\(controller.state[marker.anchorCombatantID]?.name ?? "someone")'s turn. Tap to remove.")
                }
            }
        }
        .frame(maxWidth: maxWidth)
    }

    private func color(for marker: DurationMarker) -> Color {
        let colors: [Color] = [.orange, .purple, .teal, .pink, .indigo, .brown]
        return colors[Int(marker.id.uuid.0) % colors.count]
    }
}

/// Resetting or ending the whole fight, after any `additions` the bar has no room to show beside it.
struct FightMenu<Additions: View>: View {
    let controller: BoardController
    @ViewBuilder let additions: () -> Additions
    @Environment(AppModel.self) private var model
    @State private var sharing = TableSharing.shared
    @State private var isConfirmingReset = false

    /// Says how many devices follow while the player screen is shared.
    private var shareTitle: String {
        guard sharing.isOn else { return "Share with Players…" }
        let count = sharing.followers.count
        return "Sharing with \(count) Device\(count == 1 ? "" : "s")…"
    }

    var body: some View {
        Menu("Fight", systemImage: "ellipsis.circle") {
            additions()
            PlayerNamesToggle()
            Button(shareTitle, systemImage: "dot.radiowaves.left.and.right") {
                model.librarySheet = .shareWithPlayers
            }
            Divider()
            Button("Reset Combat…", systemImage: "arrow.counterclockwise") { isConfirmingReset = true }
            Button("End Combat", systemImage: "flag.checkered") { controller.endCombat() }
        }
        .confirmationDialog("Reset this fight?", isPresented: $isConfirmingReset, titleVisibility: .visible) {
            Button("Reset Combat", role: .destructive) { controller.reset() }
        } message: {
            Text("Initiative, HP, conditions and the round go back to the start. Undo brings it all back.")
        }
    }
}

extension FightMenu where Additions == EmptyView {
    init(controller: BoardController) {
        self.init(controller: controller) { EmptyView() }
    }
}

/// Adding a creature to the fight at any time, and a duration arrow or an event once combat has begun.
struct AddToFightButtons: View {
    let controller: BoardController
    @Binding var sheet: BoardSheet?

    var body: some View {
        Button("Creature…", systemImage: "pawprint") { sheet = .creature }
        if controller.state.phase == .active {
            Button("Duration Arrow…", systemImage: "arrow.uturn.right") { sheet = .duration }
            Button("Event…", systemImage: "bell") { sheet = .event }
        }
    }
}

/// Begins combat, first warning when someone on the ladder still has no initiative.
struct BeginCombatButton: View {
    let controller: BoardController
    @State private var missing: [Combatant] = []
    @Environment(\.isCompactBoard) private var isCompact

    var body: some View {
        Button {
            missing = controller.state.combatantsWithoutInitiative
            if missing.isEmpty { controller.beginCombat() }
        } label: {
            // Across the bottom bar where the board shows the ladder alone.
            Label("Begin Combat", systemImage: "flag.checkered").frame(maxWidth: isCompact ? .infinity : nil)
        }
        .buttonStyle(.borderedProminent)
        // An alert rather than a confirmation dialog: on the iPad a dialog becomes a popover, which hides the
        // cancel button, and Go Back must always be there.
        .alert(title, isPresented: isWarning) {
            Button("Go Back", role: .cancel) { controller.highlightsMissingInitiative = true }
            Button("Begin Anyway") { controller.beginCombat() }
        } message: {
            Text("Begin Anyway puts them at the bottom of the order.")
        }
    }

    private var title: String {
        let names = missing.map(\.name)
        let list = names.count > 1
            ? names.dropLast().joined(separator: ", ") + " and " + (names.last ?? "")
            : names.first ?? ""
        return "\(list) \(names.count == 1 ? "has" : "have") no initiative yet."
    }

    private var isWarning: Binding<Bool> {
        Binding(get: { !missing.isEmpty }, set: { if !$0 { missing = [] } })
    }
}

/// Shows each PC's player after its name on the GM's ladder, as in "Valeros (Sam)". Never on the players' screen.
struct PlayerNamesToggle: View {
    static let key = "showsPlayerNames"
    @AppStorage(key) private var showsPlayerNames = true

    var body: some View {
        Toggle("Show Player Names", systemImage: "person.text.rectangle", isOn: $showsPlayerNames)
    }
}
