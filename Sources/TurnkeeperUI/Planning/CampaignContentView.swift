import TurnkeeperKit
import SwiftUI

/// A campaign's scenarios (with their encounters), parties and saved fights.
struct CampaignContentView: View {
    /// The planner passes the library's current copy, so editing the campaign redraws this list.
    let campaign: Campaign
    @Environment(AppModel.self) private var model
    @State private var isAddingScenario = false

    var body: some View {
        @Bindable var model = model
        List(selection: $model.selection) {
            Section("\(campaign.scenarioTitle)s") {
                ForEach(model.library.scenarios(in: campaign.id)) { scenario in
                    ScenarioRows(scenario: scenario, scenarioTitle: campaign.scenarioTitle)
                }
                Button("Add \(campaign.scenarioTitle)", systemImage: "plus") { isAddingScenario = true }
            }
            Section(campaign.allowsMultipleParties ? "Parties" : "Party") {
                ForEach(shownParties) { party in
                    Label("\(party.name) · level \(party.level)", systemImage: "person.3")
                        .partyIconInset()
                        .tag(PlannerSelection.party(party.id))
                        .contextMenu {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                model.library.deleteParty(party.id)
                            }
                        }
                }
                if campaign.allowsMultipleParties || shownParties.isEmpty {
                    Button("Add Party", systemImage: "plus") { model.addParty(to: campaign.id) }
                }
            }
            SavedFightsSection(campaignID: campaign.id)
        }
        .renamableTitle(campaign.name, rename: rename)
        .sheet(isPresented: $isAddingScenario) { NewScenarioSheet(campaign: campaign) }
    }

    /// Outside Society play only the first party shows; any others are kept, not deleted.
    private var shownParties: [Party] { model.shownParties(in: campaign.id) }

    private func rename(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, var current = model.library.campaigns.first(where: { $0.id == campaign.id })
        else { return }
        current.name = trimmed
        model.library.save(current)
    }
}

private extension View {
    /// The party icon is wider than most, and on the iPad it reaches past the rounded end of the row's selection
    /// highlight; a little room on the left keeps it inside.
    @ViewBuilder
    func partyIconInset() -> some View {
        #if os(iOS)
        padding(.leading, 6)
        #else
        self
        #endif
    }

    /// On the iPad the title can be tapped to rename; on the Mac, Rename… is in the sidebar's menu.
    @ViewBuilder
    func renamableTitle(_ title: String, rename: @escaping (String) -> Void) -> some View {
        #if os(iOS)
        navigationTitle(Binding(get: { title }, set: rename))
            .toolbarRole(.editor)
        #else
        navigationTitle(title)
        #endif
    }
}

/// A scenario and its encounters, indented under it.
private struct ScenarioRows: View {
    let scenario: Scenario
    let scenarioTitle: String
    @Environment(AppModel.self) private var model
    /// Collapsed scenarios on this device, as comma-separated IDs. New scenarios start expanded.
    @AppStorage("collapsedScenarios") private var collapsed = ""

    var body: some View {
        HStack {
            Button {
                toggle()
            } label: {
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 20)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(isExpanded ? "Collapse \(scenario.name)" : "Expand \(scenario.name)")
            Label(scenario.name, systemImage: "map").font(.headline)
            Spacer()
            if !isExpanded {
                Text("\(model.library.encounters(in: scenario.id).count)").foregroundStyle(.secondary)
            }
        }
        .tag(PlannerSelection.scenario(scenario.id))
        .contextMenu {
            Button("Add Encounter", systemImage: "plus") { model.addEncounter(to: scenario.id) }
            Button("Add Handout", systemImage: "doc.richtext") { model.addHandout(to: scenario.id) }
            #if os(macOS)
            OpenInPawnShopMenu(scenario: scenario, encounters: model.library.encounters(in: scenario.id),
                               title: scenario.name)
            #endif
            Button("Delete \(scenarioTitle)", systemImage: "trash", role: .destructive) {
                model.library.deleteScenario(scenario.id)
            }
        }
        if isExpanded { contents }
    }

    @ViewBuilder
    private var contents: some View {
        ForEach(model.library.encounters(in: scenario.id)) { encounter in
            Label(encounter.name, systemImage: "flame")
                .padding(.leading, 28)
                .tag(PlannerSelection.encounter(encounter.id))
                .contextMenu {
                    #if os(macOS)
                    OpenInPawnShopMenu(scenario: scenario, encounters: [encounter],
                                       title: "\(scenario.name): \(encounter.name)")
                    #endif
                    Button("Delete Encounter", systemImage: "trash", role: .destructive) {
                        model.library.deleteEncounter(encounter.id)
                    }
                }
        }
        Button("Add Encounter", systemImage: "plus") { model.addEncounter(to: scenario.id) }
            .padding(.leading, 28)
            .foregroundStyle(.secondary)
        ForEach(model.library.handouts(in: scenario.id)) { handout in
            Label(handout.name, systemImage: "doc.richtext")
                .padding(.leading, 28)
                .tag(PlannerSelection.handout(handout.id))
                .contextMenu {
                    Button("Delete Handout", systemImage: "trash", role: .destructive) {
                        model.library.deleteHandout(handout.id)
                    }
                }
        }
        Button("Add Handout", systemImage: "doc.badge.plus") { model.addHandout(to: scenario.id) }
            .padding(.leading, 28)
            .foregroundStyle(.secondary)
    }

    private var collapsedIDs: Set<String> { Set(collapsed.split(separator: ",").map(String.init)) }
    private var isExpanded: Bool { !collapsedIDs.contains(scenario.id.uuidString) }

    private func toggle() {
        var ids = collapsedIDs
        if isExpanded { ids.insert(scenario.id.uuidString) } else { ids.remove(scenario.id.uuidString) }
        withAnimation { collapsed = ids.sorted().joined(separator: ",") }
    }
}

/// Fights to continue, and finished ones to look back at.
private struct SavedFightsSection: View {
    let campaignID: UUID
    @Environment(AppModel.self) private var model

    var body: some View {
        let sessions = model.library.sessions(in: campaignID)
        let unfinished = sessions.filter { !$0.isFinished }
        let finished = sessions.filter(\.isFinished).prefix(10)
        if !unfinished.isEmpty {
            Section("Fights in progress") {
                ForEach(unfinished) { session in row(session, detail: "round \(max(session.state.round, 1))") }
            }
        }
        if !finished.isEmpty {
            Section("Finished fights") {
                ForEach(Array(finished)) { session in row(session, detail: "over") }
            }
        }
    }

    private func row(_ session: CombatSession, detail: String) -> some View {
        Button {
            model.resumeCombat(session.id)
        } label: {
            LabeledContent(session.name, value: detail)
        }
        .contextMenu {
            Button("Delete", systemImage: "trash", role: .destructive) { model.library.deleteSession(session.id) }
        }
    }
}
