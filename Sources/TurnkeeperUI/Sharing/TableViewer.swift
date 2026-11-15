import BattleCards
import TurnkeeperKit
import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Another device's player screen, followed live (R9): the initiative order and the acting combatant's card
/// back, or a handout. A tap on a strip shows that combatant's card back large; a tap there puts it away.
struct TableViewer: View {
    @State private var following = TableFollowing.shared
    @State private var shown: TableLine?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
            if let card = shownCard { enlarged(card) }
        }
        .overlay(alignment: .top) { statusBar }
        .environment(\.artPictureLoader, ArtPictureLoader { id in await TableFollowing.shared.picture(for: id) })
        .animation(.easeInOut, value: shown)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { following.returnedToForeground() }
        }
        #if os(iOS)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        // A phone propped up at the table stays awake while it follows.
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        #endif
    }

    @ViewBuilder
    private var content: some View {
        switch following.content {
        case .waiting:
            waiting
        case let .fight(lines):
            PlayerScreenLayout(lines: lines.map(\.playerLine), select: { line in
                shown = lines.first { $0.id == line.id && $0.card != nil }
            }, art: {
                if let card = following.content.activeLine?.card { RemoteCardBack(card: card) }
            })
            .padding(.top, 28)
        case let .handout(name, artID):
            VStack(spacing: 12) {
                RemotePicture(id: artID)
                Text(name).font(.title2.weight(.semibold)).foregroundStyle(.white)
            }
            .padding()
            .padding(.top, 28)
        }
    }

    /// The tapped strip's card, while that combatant is still in the fight.
    private var shownCard: TableCard? {
        guard let shown, case let .fight(lines) = following.content else { return nil }
        return lines.first { $0.id == shown.id }?.card
    }

    private func enlarged(_ card: TableCard) -> some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            RemoteCardBack(card: card).padding(24)
        }
        .contentShape(Rectangle())
        .onTapGesture { shown = nil }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(card.name), enlarged")
        .accessibilityHint("Tap to go back to the fight")
        .accessibilityAddTraits(.isButton)
        .transition(.opacity)
    }

    private var waiting: some View {
        VStack(spacing: 14) {
            if case let .refused(reason) = following.phase {
                Image(systemName: "xmark.octagon").font(.system(size: 44))
                Text("Joining \(tableName) failed: \(reason)").multilineTextAlignment(.center)
            } else if following.phase == .following {
                Image(systemName: "hourglass").font(.system(size: 44))
                Text("Waiting for the GM to start a fight").font(.title3.weight(.semibold))
            } else {
                ProgressView().controlSize(.large).tint(.white)
                Text("Looking for \(tableName)…")
            }
        }
        .foregroundStyle(.white)
        .padding(32)
    }

    /// Leaving, the table's name, and a note while the connection is being made again.
    private var statusBar: some View {
        HStack(spacing: 10) {
            Button("Leave Table", systemImage: "xmark.circle.fill") { following.leave() }
                .labelStyle(.iconOnly)
                .font(.title2)
            Text(tableName).font(.footnote.weight(.semibold)).lineLimit(1)
            if following.phase == .reconnecting {
                Label("Reconnecting…", systemImage: "arrow.triangle.2.circlepath").font(.footnote)
            }
            Spacer()
        }
        .foregroundStyle(.white.opacity(0.75))
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private var tableName: String { following.table?.name ?? "the table" }
}

/// A card back drawn from what the sharing device sent, around the art it sends when asked.
private struct RemoteCardBack: View {
    let card: TableCard
    @State private var following = TableFollowing.shared

    var body: some View {
        CardBack(name: card.name, game: card.game, traits: card.traits) {
            // Asked for again after a reconnection, in case it was lost with the old one.
            if !card.artID.isEmpty { ArtPicture(path: card.artID).id("\(card.artID)#\(following.connections)") }
        }
        .id(card)
        .transition(.opacity)
    }
}

/// A picture from the sharing device, such as a handout's.
private struct RemotePicture: View {
    let id: String
    @State private var following = TableFollowing.shared
    @State private var picture: CGImage?

    var body: some View {
        Group {
            if let picture {
                Image(decorative: picture, scale: 1).resizable().scaledToFit()
            } else {
                ProgressView().tint(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: "\(id)#\(following.connections)") { picture = await following.picture(for: id) }
    }
}
