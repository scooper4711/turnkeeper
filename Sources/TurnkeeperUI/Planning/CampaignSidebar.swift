import Bestiary
import TurnkeeperKit
import SwiftUI
import UniformTypeIdentifiers

/// The list of campaigns, with adding, deleting, importing and exporting.
struct CampaignSidebar: View {
    @Environment(AppModel.self) private var model
    @State private var renaming: Campaign?

    var body: some View {
        @Bindable var model = model
        List(selection: $model.selectedCampaignID) {
            ForEach(model.library.activeCampaigns) { campaign in
                Label(campaign.name, systemImage: campaign.game == .starfinder ? "sparkles" : "shield")
                    .tag(campaign.id)
                    .contextMenu { menu(for: campaign) }
            }
        }
        .navigationTitle("Campaigns")
        .toolbar {
            ToolbarItem { Button("Add Campaign", systemImage: "plus") { model.librarySheet = .newCampaign } }
            // The rest share one menu: a narrow sidebar hides toolbar buttons that don't fit, with no sign of them.
            ToolbarItem { moreMenu }
        }
        .sheet(item: $renaming) { campaign in CampaignSheet(campaign: campaign) }
        .onChange(of: model.selectedCampaignID) { model.selection = nil }
    }

    /// Importing, syncing, creature art and (on the iPad) About, in one menu that always fits the sidebar; the File
    /// menu has the same (`LibraryCommands`). Missing art PDFs are counted on the menu's button and its
    /// Creature Art item.
    private var moreMenu: some View {
        let missing = model.artCatalog.missingSources.count
        return Menu {
            Button("Import…", systemImage: "square.and.arrow.down") { model.isImportingLibrary = true }
            Button("Sync with Nearby Device…", systemImage: "arrow.triangle.2.circlepath") {
                model.librarySheet = .nearbySync
            }
            Button(missing > 0 ? "Creature Art (\(missing) missing)…" : "Creature Art…",
                   systemImage: "photo.on.rectangle.angled") { model.librarySheet = .creatureArt }
            // The Mac has About in the app menu.
            #if os(iOS)
            Button("About", systemImage: "info.circle") { model.librarySheet = .about }
            #endif
        } label: {
            Label("More", systemImage: missing > 0 ? "exclamationmark.circle" : "ellipsis.circle")
        }
        .badge(missing)
        .help(missing > 0 ? "Import, sync and creature art: \(missing) art PDFs are missing"
                          : "Import, sync and creature art")
    }

    @ViewBuilder
    private func menu(for campaign: Campaign) -> some View {
        Button("Rename…", systemImage: "pencil") { renaming = campaign }
        Button("Export…", systemImage: "square.and.arrow.up") { model.beginExport(of: campaign.id) }
        Button("Delete", systemImage: "trash", role: .destructive) { model.deleteCampaign(campaign.id) }
    }

}

/// Asks for a campaign's name and game, for a new campaign or to rename one.
struct CampaignSheet: View {
    /// The campaign being renamed, or nil to add one.
    let campaign: Campaign?
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var game = Game.pathfinder

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name, prompt: Text("PFS Season 7"))
                    .nameEntry()
                Picker("Game", selection: $game) {
                    Text("Pathfinder").tag(Game.pathfinder)
                    Text("Starfinder").tag(Game.starfinder)
                }
                .pickerStyle(.segmented)
            }
            .formStyle(.grouped)
            .navigationTitle(campaign == nil ? "New Campaign" : "Rename Campaign")
            .onAppear {
                name = campaign?.name ?? ""
                game = campaign?.game ?? .pathfinder
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(campaign == nil ? "Add" : "Save", action: save)
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
        .frame(minWidth: 360, minHeight: 200)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    private func save() {
        if var campaign {
            campaign.name = trimmedName
            campaign.game = game
            model.library.save(campaign)
        } else {
            model.addCampaign(name: trimmedName, game: game)
        }
        dismiss()
    }
}

/// A `.turnkeeper` file for the exporter.
struct LibraryDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.turnkeeperLibrary]
    var data: Data
    var fileName: String

    init(data: Data, fileName: String) {
        self.data = data
        self.fileName = fileName
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
        fileName = configuration.file.filename ?? "Turnkeeper.turnkeeper"
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
