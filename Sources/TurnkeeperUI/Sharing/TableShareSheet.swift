import TurnkeeperKit
import SwiftUI

/// Turns sharing the player screen with the players' devices on and off, and shows the code they join with.
struct TableShareSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sharing = TableSharing.shared

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Share the Player Screen", isOn: isOn)
                } footer: {
                    Text("Players follow the fight on their own iPhone, iPad or Mac: the initiative order, how hurt "
                         + "each enemy looks, handouts, and the art of anyone they tap. Never a stat block or a "
                         + "number.")
                }
                if sharing.isOn {
                    codeSection
                    followersSection
                }
                if !sharing.errorMessage.isEmpty { Section { Text(sharing.errorMessage) } }
            }
            .formStyle(.grouped)
            .navigationTitle("Share with Players")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .sheetFrame(minWidth: 460, minHeight: 460)
    }

    private var codeSection: some View {
        Section {
            Text(sharing.code).font(.system(size: 56, weight: .bold, design: .rounded).monospacedDigit())
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Code \(sharing.code)")
            Text("On each player's device, open Turnkeeper, choose Follow a Table from the More menu, pick "
                 + "\(DeviceName.current), and enter this code. Everyone must be on the same Wi-Fi network.")
                .foregroundStyle(.secondary)
        }
    }

    private var followersSection: some View {
        Section("Following") {
            if sharing.followers.isEmpty {
                Text("No one yet").foregroundStyle(.secondary)
            }
            ForEach(Array(sharing.followers.enumerated()), id: \.offset) { _, name in
                Label(name, systemImage: "iphone")
            }
        }
    }

    private var isOn: Binding<Bool> {
        Binding(get: { sharing.isOn }, set: { isOn in
            if isOn { Task { await sharing.start() } } else { sharing.stop() }
        })
    }
}

/// Picks a device sharing its player screen, and joins it with its code.
struct FollowTableSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var browser: TableBrowser?
    @State private var tables: [TablePeer] = []
    @State private var selected: TablePeer?
    @State private var code = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if tables.isEmpty { ProgressView("Looking for a GM sharing the player screen…") }
                    ForEach(tables) { table in
                        Button { selected = table } label: {
                            Label(table.name, systemImage: table == selected ? "checkmark.circle.fill" : "circle")
                        }
                    }
                } header: {
                    Text("Tables nearby")
                } footer: {
                    Text("The GM chooses Share with Players in Turnkeeper, on the same Wi-Fi network.")
                }
                Section {
                    TextField("Code", text: $code)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                } footer: {
                    Text("The four digits on the GM's device.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Follow a Table")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Follow", action: follow)
                        .disabled(selected == nil || code.filter(\.isNumber).count < 4)
                }
            }
            .task { browse() }
            .onDisappear { browser?.stop() }
        }
        .sheetFrame(minWidth: 460, minHeight: 420)
    }

    private func browse() {
        let browser = TableBrowser()
        browser.start { found in Task { @MainActor in show(found) } }
        self.browser = browser
    }

    /// Chooses the table followed last, with its code, or the only one there is.
    private func show(_ found: [TablePeer]) {
        tables = found
        if let selected, found.contains(selected) { return }
        if let remembered = TableFollowing.shared.remembered, found.contains(remembered.table) {
            selected = remembered.table
            if code.isEmpty { code = remembered.code }
        } else {
            selected = found.count == 1 ? found[0] : nil
        }
    }

    private func follow() {
        guard let selected else { return }
        TableFollowing.shared.join(selected, code: code)
        dismiss()
    }
}
