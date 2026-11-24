import SwiftUI

/// A live frequency display that shows the screen is listening: bars that move with what the microphone picks
/// up, and lie flat in silence. With Reduce Motion the bars change without animating.
struct ListeningMeter: View {
    let levels: [Float]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(levels.indices, id: \.self) { index in
                Capsule()
                    .fill(.tint)
                    .frame(maxWidth: 10)
                    .frame(height: max(CGFloat(levels[index]) * 44, 3))
            }
        }
        .frame(height: 44)
        .animation(reduceMotion ? nil : .spring(duration: 0.12), value: levels)
        .accessibilityElement()
        .accessibilityLabel("Listening level")
        .accessibilityValue(levels.contains { $0 > 0.2 } ? "Hearing sound" : "Quiet")
    }
}

/// Done on the voice initiative screen: a red stop button that pulses slowly while listening, or glows steadily
/// with Reduce Motion. It stops listening and closes the screen.
struct PulsingStopButton: View {
    let isListening: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    var body: some View {
        Button(action: action) {
            Label("Done", systemImage: "stop.circle.fill")
                .font(.title2.bold())
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .foregroundStyle(.white)
                .background(.red, in: Capsule())
                .shadow(color: .red.opacity(isListening ? 0.7 : 0), radius: glowRadius)
                .scaleEffect(isAnimating && isPulsing ? 1.06 : 1)
                .opacity(isAnimating && isPulsing ? 0.85 : 1)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.defaultAction)
        .accessibilityLabel("Done")
        .accessibilityIdentifier("voiceDone")
        .onAppear { isPulsing = true }
        .animation(isAnimating ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true) : nil,
                   value: isPulsing)
    }

    private var isAnimating: Bool { isListening && !reduceMotion }

    private var glowRadius: CGFloat {
        guard isListening else { return 0 }
        return reduceMotion ? 10 : (isPulsing ? 14 : 4)
    }
}
