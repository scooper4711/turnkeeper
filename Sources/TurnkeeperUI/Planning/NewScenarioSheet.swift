import TurnkeeperKit
import SwiftUI

/// Asks for a scenario's name and, in Society play, its difficulty scheme.
struct NewScenarioSheet: View {
    let campaign: Campaign
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var scheme = VariantScheme.single
    @State private var labels = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name, prompt: Text(namePrompt)).titleEntry()
                if campaign.allowsDifficultyVariants { variantFields }
            }
            .formStyle(.grouped)
            .navigationTitle("New \(campaign.scenarioTitle)")
            .onAppear { scheme = .easierBaseHarder }
            .onChange(of: scheme, initial: true) { labels = scheme.labels.joined(separator: ", ") }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Add", action: add) }
            }
        }
        .sheetFrame(minWidth: 420, minHeight: 280)
    }

    private var namePrompt: String { campaign.isSociety ? "#7-03: The Sunken Vault" : "Chapter 1" }

    @ViewBuilder
    private var variantFields: some View {
        Picker("Difficulty variants", selection: $scheme) {
            ForEach(VariantScheme.choices(society: true), id: \.self) { Text($0.title).tag($0) }
        }
        TextField("Variant labels, comma separated", text: $labels)
        Text("The labels can be edited to match the scenario being run.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private func add() {
        let parsed = labels.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let fallbackName = "New \(campaign.scenarioTitle.lowercased())"
        model.addScenario(to: campaign.id, name: name.isEmpty ? fallbackName : name, labels: parsed)
        dismiss()
    }
}
