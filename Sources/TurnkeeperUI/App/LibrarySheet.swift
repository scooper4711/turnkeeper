import AppNotices
import SwiftUI

/// A sheet about the whole library, opened from the campaign sidebar's toolbar or the File menu.
enum LibrarySheet: String, Identifiable {
    case newCampaign
    case nearbySync
    case creatureArt
    case about

    var id: String { rawValue }

    @ViewBuilder @MainActor
    var content: some View {
        switch self {
        case .newCampaign: CampaignSheet(campaign: nil)
        case .nearbySync: NearbySyncSheet()
        case .creatureArt: CreatureArtView()
        case .about: AboutSheet(info: .turnkeeper)
        }
    }
}

extension AppModel {
    /// Prepares a campaign's file for the exporter in `RootView`, which asks where to save it.
    func beginExport(of campaignID: UUID) {
        do {
            campaignExport = LibraryDocument(data: try exportCampaign(campaignID),
                                             fileName: exportFileName(for: campaignID))
        } catch {
            let name = library.activeCampaigns.first { $0.id == campaignID }?.name ?? "the campaign"
            errorMessage = "Exporting \(name) failed: \(error.localizedDescription)"
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
            Button("Export Campaign…") {
                if let id = model.selectedCampaignID { model.beginExport(of: id) }
            }
            .disabled(model.selectedCampaignID == nil)
            Divider()
            Button("Sync with Nearby Device…") { model.librarySheet = .nearbySync }
            Button("Creature Art…") { model.librarySheet = .creatureArt }
        }
    }

    private var newCampaign: some View {
        Button("New Campaign…") { model.librarySheet = .newCampaign }
            .keyboardShortcut("n")
    }
}
