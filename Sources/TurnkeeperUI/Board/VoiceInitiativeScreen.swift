import TurnkeeperKit
import SwiftUI

/// Setup's voice initiative screen (R4.3): it listens the whole time it's open. Saying a name selects that row,
/// and a number said for the selected row records it and moves on to the next row without one. PC rows are
/// dragged to change the seating order. Only Done closes it, so a wrong number can be said again. Until the GM
/// turns it off, `VoiceInitiativeHelp` explains all this before listening starts.
struct VoiceInitiativeScreen: View {
    let controller: BoardController
    @Environment(\.dismiss) private var dismiss
    @State private var voice = VoiceInitiative.shared
    @State private var showsAll = false
    @State private var selectedID: UUID?
    @State private var sparklingID: UUID?
    @State private var status = ""
    @State private var showsHelp = false
    /// The help opened by itself, so listening starts once it closes.
    @State private var isIntroducing = false
    @AppStorage(VoiceInitiativeHelp.hiddenKey) private var hidesHelp = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(roster.pcs) { row($0) }
                        .onMove { controller.moveSeat(from: $0, to: $1) }
                } footer: {
                    if roster.pcs.count > 1 { Text("Drag players into the order they sit around the table.") }
                }
                if showsAll && !roster.creatures.isEmpty {
                    Section("Creatures") { ForEach(roster.creatures) { row($0) } }
                }
            }
            .safeAreaInset(edge: .bottom) { footer }
            .navigationTitle("Voice Initiative")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("How It Works", systemImage: "questionmark.circle") { showsHelp = true }
                    Toggle("Show All", isOn: $showsAll)
                }
            }
        }
        .sheetFrame(minWidth: 520, minHeight: 640)
        .interactiveDismissDisabled()
        .task { await open() }
        .sheet(isPresented: $showsHelp, onDismiss: startAfterIntroduction) {
            VoiceInitiativeHelp(isIntroduction: isIntroducing)
        }
        .onDisappear { voice.stop() }
        .onChange(of: showsAll) {
            if !roster.rows.contains(where: { $0.id == selectedID }) { selectedID = firstSelection }
        }
    }

    private var roster: InitiativeRoster { controller.voiceRoster(showsAll: showsAll) }

    private var firstSelection: UUID? { roster.firstOpen ?? roster.rows.first?.id }

    private func row(_ combatant: Combatant) -> some View {
        let isSelected = combatant.id == selectedID
        return VoiceInitiativeRow(
            combatant: combatant, isSelected: isSelected, isSparkling: combatant.id == sparklingID,
            skills: isSelected ? controller.initiativeSkills(for: combatant) : []
        )
        .onTapGesture { selectedID = combatant.id }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            ListeningMeter(levels: voice.levels)
            Text(voice.transcript.isEmpty ? prompt : voice.transcript)
                .font(.title3.monospacedDigit())
                .lineLimit(2)
                .accessibilityIdentifier("voiceTranscript")
            Text(voice.isAvailable ? status : voice.unavailableReason)
                .font(.callout)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("voiceStatus")
            PulsingStopButton(isListening: voice.isListening) {
                voice.stop()
                dismiss()
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private var prompt: String {
        voice.isListening ? "Say a name or a number…" : ""
    }

    private var selectedName: String { selectedID.flatMap { controller.state[$0]?.name } ?? "" }

    // MARK: Listening

    /// Selects the first row and starts listening, or first explains how, until the GM turns that off.
    private func open() async {
        selectedID = firstSelection
        guard hidesHelp else {
            isIntroducing = true
            showsHelp = true
            return
        }
        await start()
    }

    private func startAfterIntroduction() {
        guard isIntroducing else { return }
        isIntroducing = false
        Task { await start() }
    }

    private func start() async {
        await voice.requestPermission()
        let names = controller.state.ladder.flatMap { [$0.name, $0.playerName] }.filter { !$0.isEmpty }
        voice.start(names: names, onPartial: { selectName(in: $0) }, onUtterance: { record($0) })
        if voice.isListening { status = "Listening for \(selectedName)" }
    }

    /// Selects the row a name in the transcript means. True when one was named.
    @discardableResult
    private func selectName(in transcript: String) -> Bool {
        let rows = roster.rows
        guard let id = roster.pick(controller.spokenNames(of: rows).matches(in: transcript)) else { return false }
        if id != selectedID { selectedID = id }
        return true
    }

    /// A finished utterance: a number goes to the selected row, which then moves on.
    private func record(_ utterance: String) {
        let named = selectName(in: utterance)
        guard let heard = SpokenNumberParser.spokenInitiative(from: utterance) else {
            status = named ? "Listening for \(selectedName)" : "Didn't catch a number in “\(utterance)”"
            return
        }
        guard let id = selectedID, let name = controller.state[id]?.name else {
            status = "Tap a row first."
            return
        }
        let value = controller.recordSpoken(heard, for: id)
        status = "Heard \(InitiativeText.format(value)) for \(name)"
            + (heard.isNatural && value != heard.value ? " (natural \(InitiativeText.format(heard.value)))" : "")
        if heard.isNatural && heard.value == 20 { sparkle(id) }
        selectedID = roster.nextOpen(after: id) ?? id
    }

    private func sparkle(_ id: UUID) {
        withAnimation { sparklingID = id }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            if sparklingID == id { withAnimation { sparklingID = nil } }
        }
    }
}
