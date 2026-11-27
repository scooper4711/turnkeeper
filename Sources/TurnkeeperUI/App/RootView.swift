import BattleCards
import TurnkeeperKit
import SwiftUI

/// The planner, or the combat board while a fight is open.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var following = TableFollowing.shared
    @State private var isAskingForUpdate = false

    var body: some View {
        @Bindable var model = model
        Group {
            if let key = Self.demoCardBackKey {
                // `--demo back <key>`: one creature's player view, for checking card backs.
                if let entry = model.entry(key) { CardBackView(entry: entry) }
            } else if let session = model.activeSession {
                BoardView(sessionID: session.id)
            } else {
                PlannerView()
            }
        }
        .environment(\.boardTheme, BoardTheme.forGame(model.game))
        .battleCardEnvironment(model)
        .battleCardFullScreenHost()
        .alert("Turnkeeper", isPresented: errorBinding) {
            if let url = model.errorSheetURL {
                Button("Open on Demiplane") {
                    openURL(url)
                    clearError()
                }
            }
            Button("OK") { clearError() }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .onChange(of: model.needsUpdateToSync, initial: true) { isAskingForUpdate = model.needsUpdateToSync }
        .alert("Update Turnkeeper", isPresented: $isAskingForUpdate) {
            Button("OK") {}
        } message: {
            Text("""
                Another of your devices has a newer version of Turnkeeper. Its changes won't show here, and some \
                changes made here won't reach it, until Turnkeeper is updated on this device.
                """)
        }
        .overlay(alignment: .bottom) { StatusToast() }
        // Over everything, and nothing under it is closed: a GM's device can follow another table and come back.
        .overlay { if following.isViewerOpen { TableViewer().transition(.opacity) } }
        .animation(.easeInOut, value: following.isViewerOpen)
        // Here rather than in the sidebar, which isn't there while it is hidden or a fight is on screen.
        .sheet(item: $model.librarySheet) { $0.content }
        .fileImporter(isPresented: $model.isImportingLibrary,
                      allowedContentTypes: [.turnkeeperLibrary, .json]) { result in
            if case let .success(url) = result { model.importLibraryFile(url) }
        }
        .sheet(item: $model.exportSelection) { ExportSheet(selection: $0) }
    }

    private static var demoCardBackKey: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--demo"), arguments.indices.contains(index + 2),
              arguments[index + 1] == "back" else { return nil }
        return arguments[index + 2]
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { model.errorMessage != nil }, set: { if !$0 { clearError() } })
    }

    private func clearError() {
        model.errorMessage = nil
        model.errorSheetURL = nil
    }
}

/// A passing message at the bottom of the window that fades after a few seconds.
private struct StatusToast: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let message = model.statusMessage {
            Text(message)
                .font(.callout)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, 24)
                .task(id: message) {
                    try? await Task.sleep(for: .seconds(5))
                    model.statusMessage = nil
                }
                .onTapGesture { model.statusMessage = nil }
        }
    }
}
