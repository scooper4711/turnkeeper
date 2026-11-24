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

    /// Importing, creature art and (on the iPad) About, in one menu that always fits the sidebar; the File
    /// menu has the same (`LibraryCommands`). Missing art PDFs are counted on the menu's button and its
    /// Creature Art item.
    private var moreMenu: some View {
        let missing = model.artSourcesNeeded.count
        return Menu {
            Button("Import…", systemImage: "square.and.arrow.down") { model.isImportingLibrary = true }
            Button(model.cloudSyncStatusText, systemImage: "icloud") {}.disabled(true)
            Button(missing > 0 ? "Creature Art (\(missing) missing)…" : "Creature Art…",
                   systemImage: "photo.on.rectangle.angled") { model.librarySheet = .creatureArt }
            Divider()
            Button("Share with Players…", systemImage: "dot.radiowaves.left.and.right") {
                model.librarySheet = .shareWithPlayers
            }
            Button("Follow a Table…", systemImage: "person.2.wave.2") { model.librarySheet = .followTable }
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
        Button("Edit…", systemImage: "pencil") { renaming = campaign }
        Button("Export…", systemImage: "square.and.arrow.up") { model.beginExport(of: campaign.id) }
        Button("Delete", systemImage: "trash", role: .destructive) { model.deleteCampaign(campaign.id) }
    }

}

/// Asks for a campaign's name, game and whether it is Society play, for a new campaign or to edit one.
struct CampaignSheet: View {
    /// The campaign being edited, or nil to add one.
    let campaign: Campaign?
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var game = Game.pathfinder
    @State private var isSociety = false
    @State private var eventID = ""
    /// The last choice made when adding a campaign, so a Society GM gets the box checked and a home GM doesn't.
    @AppStorage("lastCampaignWasSociety") private var lastWasSociety = false

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
                Toggle("Society play (PFS or SFS)", isOn: $isSociety)
                if isSociety {
                    TextField("Event ID", text: $eventID)
                    Text("Information only for now.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("\(campaign == nil ? "New" : "Edit") \(isSociety ? "Event" : "Campaign")")
            .onAppear {
                name = campaign?.name ?? ""
                game = campaign?.game ?? .pathfinder
                isSociety = campaign?.isSociety ?? lastWasSociety
                eventID = campaign?.eventID ?? ""
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(campaign == nil ? "Add" : "Save", action: save)
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
        .sheetFrame(minWidth: 360, minHeight: 260)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    private var trimmedEventID: String { isSociety ? eventID.trimmingCharacters(in: .whitespaces) : "" }

    private func save() {
        if var campaign {
            campaign.name = trimmedName
            campaign.game = game
            campaign.isSociety = isSociety
            campaign.eventID = trimmedEventID
            model.library.save(campaign)
        } else {
            lastWasSociety = isSociety
            model.addCampaign(NewCampaign(name: trimmedName, game: game, isSociety: isSociety,
                                          eventID: trimmedEventID))
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
