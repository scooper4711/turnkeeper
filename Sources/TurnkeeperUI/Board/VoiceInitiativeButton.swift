import TurnkeeperKit
import SwiftUI

/// Setup's voice entry: one large button below the ladder that opens the voice initiative screen.
struct VoiceInitiativeButton: View {
    let controller: BoardController
    @Binding var sheet: BoardSheet?

    var body: some View {
        Button { sheet = .voiceInitiative } label: {
            Label("Voice Initiative", systemImage: "mic.fill")
                .font(.title2.bold())
                // Beside the strips on an iPhone on its side, the title has half the room.
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 8)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(.black.opacity(0.45), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("Say each player's initiative; press I")
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}
