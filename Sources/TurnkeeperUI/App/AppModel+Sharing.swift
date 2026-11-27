import TurnkeeperKit
import Foundation

/// `.turnkeeper` files in both directions.
extension AppModel {
    /// Opens the export dialog for a campaign (R1.2a) with one of the planner's items checked, or with
    /// everything checked when there is none.
    func beginExport(of item: PlannerSelection?, in campaignID: UUID) {
        guard let item else {
            exportSelection = .everything(in: campaignID, of: library)
            return
        }
        var picked = ExportSelection(campaignID: campaignID)
        if let line = exportItem(item) { picked.include(line, from: library) }
        exportSelection = picked
    }

    /// The planner's item as a line of the export dialog, if it still exists.
    private func exportItem(_ item: PlannerSelection) -> ExportItem? {
        switch item {
        case let .scenario(id): scenario(id).map(ExportItem.scenario)
        case let .encounter(id): encounter(id).map(ExportItem.encounter)
        case let .handout(id): handout(id).map(ExportItem.handout)
        case let .party(id): party(id).map(ExportItem.party)
        }
    }

    /// What's checked in the export dialog, as a `.turnkeeper` file for the exporter.
    func exportDocument(for selection: ExportSelection) throws -> LibraryDocument {
        markSent()
        let package = LibraryPackage(picking: selection, from: library,
                                     bestiaryRevision: bestiary.index.sourceRevision)
        return LibraryDocument(data: try withImages(package).encoded(), fileName: selection.fileName(in: library))
    }

    /// Records that every record's current version has left this device, so when the other device sends it
    /// back unchanged, the merge knows it's this device's own earlier version and not an edit made there.
    private func markSent() {
        let sent = library.sending()
        if sent != library { library = sent }
    }

    private func withImages(_ package: LibraryPackage) -> LibraryPackage {
        artStore.map { package.addingImages(from: $0, artStore: pastedArtStore) } ?? package
    }

    /// Merges a `.turnkeeper` file into the library and reports what changed.
    func importLibraryFile(_ url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            importPackage(try LibraryPackage.decode(Data(contentsOf: url)))
        } catch {
            errorMessage = "Importing \(url.lastPathComponent) failed: \(error.localizedDescription)"
        }
    }

    func importPackage(_ package: LibraryPackage) {
        do {
            if let artStore { try package.writeImages(to: artStore, artStore: pastedArtStore) }
        } catch {
            errorMessage = error.localizedDescription
        }
        var merged = library
        let summary = LibraryMerger.merge(package.library, into: &merged)
        library = merged
        campaignSync?.libraryMerged()
        if selectedCampaignID == nil { selectedCampaignID = library.activeCampaign(preferring: nil)?.id }
        statusMessage = describe(summary, package: package)
    }

    private func describe(_ summary: MergeSummary, package: LibraryPackage) -> String {
        guard summary.changedAnything else { return "Already up to date." }
        var parts = ["\(summary.added) added", "\(summary.updated) updated", "\(summary.deleted) deleted"]
        if summary.conflicts > 0 {
            parts.append("\(summary.conflicts) edited on both devices, kept as conflict copies")
        }
        var message = "Merged: " + parts.joined(separator: ", ") + "."
        if !package.bestiaryRevision.isEmpty && package.bestiaryRevision != bestiary.index.sourceRevision {
            message += " The other device has a different bestiary import; re-run the import on both to match."
        }
        return message
    }
}
