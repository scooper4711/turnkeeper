#if os(macOS)
import SwiftUI
import TurnkeeperKit

/// Open in Pawn Shop, in the context menu of a scenario or an encounter (R3.9): one item, or where the scenario
/// shows several difficulties a submenu with All Difficulties first. Nothing without a Pawn Shop to open it in.
struct OpenInPawnShopMenu: View {
    let scenario: Scenario
    /// The scenario's encounters, or the one whose menu this is.
    let encounters: [Encounter]
    /// What to call the sheet: the scenario, or the scenario and the encounter.
    let title: String
    @Environment(AppModel.self) private var model

    private static let name = "Open in Pawn Shop"
    private static let symbol = "printer"

    var body: some View {
        if model.canOpenInPawnShop {
            let labels = model.shownVariantLabels(of: scenario)
            if labels.count > 1 {
                Menu(Self.name, systemImage: Self.symbol) {
                    Button("All Difficulties") { open(labels, titled: title) }
                    Divider()
                    ForEach(labels, id: \.self) { label in
                        Button(label) { open([label], titled: "\(title) (\(label))") }
                            .disabled(!PawnTally(encounters: encounters, labels: [label]).hasCreatures)
                    }
                }
                .disabled(!PawnTally(encounters: encounters, labels: labels).hasCreatures)
            } else {
                Button(Self.name, systemImage: Self.symbol) { open(labels, titled: title) }
                    .disabled(!PawnTally(encounters: encounters, labels: labels).hasCreatures)
            }
        }
    }

    private func open(_ labels: [String], titled title: String) {
        model.openInPawnShop(PawnTally(encounters: encounters, labels: labels), titled: title)
    }
}
#endif
