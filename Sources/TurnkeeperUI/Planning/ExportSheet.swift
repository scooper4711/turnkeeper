import SwiftUI
import TurnkeeperKit

/// Asks what to put in a `.turnkeeper` file (R1.2a): a campaign's scenarios with their encounters and handouts,
/// and its parties, each with a check mark. Export… then asks where to save the file.
struct ExportSheet: View {
    /// What's checked, starting from what Export… was chosen on.
    @State var selection: ExportSelection
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    /// The file waiting for the user to choose where to save it.
    @State private var document: LibraryDocument?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    selectAllRow
                } footer: {
                    Text("""
                        Custom creatures, pasted art and creature notes go with the encounters that use them. \
                        Saved fights stay on this device.
                        """)
                }
                Section("\(campaign?.scenarioTitle ?? "Scenario")s") {
                    ForEach(model.library.scenarios(in: selection.campaignID)) { scenario in
                        ScenarioChecks(scenario: scenario, selection: $selection)
                    }
                }
                Section(campaign?.allowsMultipleParties == false ? "Party" : "Parties") {
                    ForEach(model.shownParties(in: selection.campaignID)) { party in
                        CheckRow(title: "\(party.name) · level \(party.level)", systemImage: "person.3",
                                 isOn: $selection.isChecked(.party(party), in: model.library))
                    }
                }
            }
            .navigationTitle("Export \(campaign?.name ?? "")")
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Export…", action: export).disabled(selection.isEmpty)
                }
            }
        }
        .sheetFrame(minWidth: 420, minHeight: 520)
        // Over the sheet, which stays open when the save is canceled so the choices aren't lost.
        .fileExporter(isPresented: documentBinding, document: document, contentType: .turnkeeperLibrary,
                      defaultFilename: document?.fileName, onCompletion: finish)
    }

    private var campaign: Campaign? { model.campaign(selection.campaignID) }

    private var selectAllRow: some View {
        HStack {
            Button("Select All") { selection.includeAll(from: model.library) }
            Spacer()
            Button("Select None") { selection.excludeAll() }
        }
        // Two plain buttons in one row would both fire on a tap anywhere in it.
        .buttonStyle(.borderless)
    }

    private var documentBinding: Binding<Bool> {
        Binding(get: { document != nil }, set: { if !$0 { document = nil } })
    }

    private func export() {
        do {
            document = try model.exportDocument(for: selection)
        } catch {
            close(reporting: "Exporting failed: \(error.localizedDescription)")
        }
    }

    private func finish(_ result: Result<URL, any Error>) {
        document = nil
        switch result {
        case .success: dismiss()
        // A canceled save isn't a failure: the sheet stays as it was.
        case let .failure(error as CocoaError) where error.code == .userCancelled: break
        case let .failure(error): close(reporting: "Saving the export failed: \(error.localizedDescription)")
        }
    }

    /// The error shows in the window's alert, which can't open while the sheet is up.
    private func close(reporting message: String) {
        dismiss()
        model.errorMessage = message
    }
}

/// A scenario's line, with its encounters and handouts indented under it.
private struct ScenarioChecks: View {
    let scenario: Scenario
    @Binding var selection: ExportSelection
    @Environment(AppModel.self) private var model

    var body: some View {
        CheckRow(title: scenario.name, systemImage: "map", isOn: isChecked(.scenario(scenario)))
            .font(.headline)
        ForEach(model.library.encounters(in: scenario.id)) { encounter in
            CheckRow(title: encounter.name, systemImage: "flame", isOn: isChecked(.encounter(encounter)))
                .padding(.leading, 28)
        }
        ForEach(model.library.handouts(in: scenario.id)) { handout in
            CheckRow(title: handout.name, systemImage: "doc.richtext", isOn: isChecked(.handout(handout)))
                .padding(.leading, 28)
        }
    }

    private func isChecked(_ item: ExportItem) -> Binding<Bool> {
        $selection.isChecked(item, in: model.library)
    }
}

/// A line with a check mark that a tap turns on or off.
private struct CheckRow: View {
    let title: String
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .imageScale(.large)
                Label(title, systemImage: systemImage)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

private extension Binding where Value == ExportSelection {
    /// Whether an item is checked; setting it checks or clears the item and what goes with it.
    func isChecked(_ item: ExportItem, in library: Library) -> Binding<Bool> {
        Binding<Bool>(get: { wrappedValue.contains(item) }, set: { isOn in
            if isOn {
                wrappedValue.include(item, from: library)
            } else {
                wrappedValue.exclude(item, from: library)
            }
        })
    }
}

private extension View {
    /// On the iPad and the iPhone the title sits in the bar, where a long campaign name still fits.
    @ViewBuilder
    func inlineTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
