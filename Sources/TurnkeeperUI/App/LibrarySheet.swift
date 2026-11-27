import AppNotices
import SwiftUI

/// A sheet about the whole library, opened from the campaign sidebar's toolbar or the File menu.
enum LibrarySheet: String, Identifiable {
    case newCampaign
    case creatureArt
    case shareWithPlayers
    case followTable
    case about

    var id: String { rawValue }

    @ViewBuilder @MainActor
    var content: some View {
        switch self {
        case .newCampaign: CampaignSheet(campaign: nil)
        case .creatureArt: CreatureArtView()
        case .shareWithPlayers: TableShareSheet()
        case .followTable: FollowTableSheet()
        case .about: AboutSheet(info: .turnkeeper)
        }
    }
}

/// The campaign sidebar's buttons as File menu commands, so they're there however narrow or hidden the sidebar is.
/// On the iPad they show in the menu bar a keyboard brings up.
struct LibraryCommands: Commands {
    let model: AppModel

    var body: some Commands {
        // Every window shows the same library, so a new campaign takes the place of New Window, and its ⌘N.
        // The iPad app must replace it too: run on a Mac, keeping New Window ⌘N beside it crashes at launch.
        CommandGroup(replacing: .newItem) { newCampaign }
        CommandGroup(after: .importExport) {
            Button("Import Library…") { model.isImportingLibrary = true }
            Button("Export…") {
                if let id = model.selectedCampaignID { model.beginExport(of: model.selection, in: id) }
            }
            .disabled(model.selectedCampaignID == nil)
            Divider()
            Button(model.cloudSyncStatusText) {}.disabled(true)
            Button("Creature Art…") { model.librarySheet = .creatureArt }
            Divider()
            Button("Share with Players…") { model.librarySheet = .shareWithPlayers }
            Button("Follow a Table…") { model.librarySheet = .followTable }
        }
    }

    private var newCampaign: some View {
        Button("New Campaign…") { model.librarySheet = .newCampaign }
            .keyboardShortcut("n")
    }
}
