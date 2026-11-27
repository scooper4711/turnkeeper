import SwiftUI
import TurnkeeperKit

/// One way of handing over a sheet of pawns: what its menu item says, whose pawns, and what to call the sheet.
struct PawnSheetHandoff {
    let text: String
    /// The item's symbol; none inside the submenu of difficulties.
    let symbol: String?
    let tally: PawnTally
    let title: String

    @ViewBuilder var label: some View {
        if let symbol { Label(text, systemImage: symbol) } else { Text(text) }
    }
}

/// The pawns of a scenario or an encounter, in its context menu (R3.9): one item, or where the scenario shows
/// several difficulties a submenu with All Difficulties first. `item` makes the control that hands a sheet over,
/// which differs between the Mac (a link) and the iPad and iPhone (the share sheet).
struct PawnSheetMenu<Item: View>: View {
    let name: String
    let symbol: String
    let scenario: Scenario
    /// The scenario's encounters, or the one whose menu this is.
    let encounters: [Encounter]
    /// What to call the sheet: the scenario, or the scenario and the encounter.
    let title: String
    @ViewBuilder let item: (PawnSheetHandoff) -> Item
    @Environment(AppModel.self) private var model

    var body: some View {
        let labels = model.shownVariantLabels(of: scenario)
        if labels.count > 1 {
            Menu(name, systemImage: symbol) {
                control(PawnSheetHandoff(text: "All Difficulties", symbol: nil, tally: tally(labels), title: title))
                Divider()
                ForEach(labels, id: \.self) { label in
                    control(PawnSheetHandoff(text: label, symbol: nil, tally: tally([label]),
                                             title: "\(title) (\(label))"))
                }
            }
            .disabled(!tally(labels).hasCreatures)
        } else {
            control(PawnSheetHandoff(text: name, symbol: symbol, tally: tally(labels), title: title))
        }
    }

    private func tally(_ labels: [String]) -> PawnTally {
        PawnTally(encounters: encounters, labels: labels)
    }

    private func control(_ handoff: PawnSheetHandoff) -> some View {
        item(handoff).disabled(!handoff.tally.hasCreatures)
    }
}

#if os(macOS)
/// Open in Pawn Shop, on the Mac (R3.9). Nothing without a Pawn Shop to open the sheet in.
struct OpenInPawnShopMenu: View {
    let scenario: Scenario
    let encounters: [Encounter]
    let title: String
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.canOpenInPawnShop {
            PawnSheetMenu(name: "Open in Pawn Shop", symbol: "printer", scenario: scenario,
                          encounters: encounters, title: title) { handoff in
                Button { model.openInPawnShop(handoff.tally, titled: handoff.title) } label: { handoff.label }
            }
        }
    }
}
#else
/// Share Pawn Sheet, on the iPad and iPhone (R3.9.5): the share sheet, where choosing Pawn Shop opens the sheet.
/// Always shown: the sheet can also go to a Mac or to someone else.
struct SharePawnSheetMenu: View {
    let scenario: Scenario
    let encounters: [Encounter]
    let title: String
    @Environment(AppModel.self) private var model

    var body: some View {
        PawnSheetMenu(name: "Share Pawn Sheet", symbol: "square.and.arrow.up", scenario: scenario,
                      encounters: encounters, title: title) { handoff in
            Button { model.sharePawnSheet(handoff.tally, titled: handoff.title) } label: { handoff.label }
        }
    }
}
#endif

/// The context menu's way to Pawn Shop on this device: Open in Pawn Shop on the Mac, Share Pawn Sheet elsewhere.
#if os(macOS)
typealias PawnSheetItem = OpenInPawnShopMenu
#else
typealias PawnSheetItem = SharePawnSheetMenu
#endif
