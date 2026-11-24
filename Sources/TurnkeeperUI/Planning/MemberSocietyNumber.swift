import TurnkeeperKit
import SwiftUI

/// A member's Organized Play ID and character number, as "123456 - 2001".
struct MemberSocietyNumber: View {
    @Binding var societyID: String
    @Binding var characterNumber: String
    @ScaledMetric private var idWidth = 92.0
    @ScaledMetric private var numberWidth = 52.0

    var body: some View {
        HStack(spacing: 4) {
            DigitsField(prompt: "Org Play ID", limit: SocietyNumber.organizedPlayIDLength, value: $societyID)
                .multilineTextAlignment(.trailing)
                .frame(width: idWidth)
            Text("-").foregroundStyle(.secondary)
            DigitsField(prompt: "Char #", limit: SocietyNumber.characterNumberLength, value: $characterNumber)
                .frame(width: numberWidth)
        }
        .monospacedDigit()
    }
}

/// A text field that takes digits only, up to a length. The prompt is also its name for VoiceOver.
private struct DigitsField: View {
    let prompt: String
    let limit: Int
    @Binding var value: String
    /// What the field shows. Kept apart from `value` so a rejected key is taken out of the field again.
    @State private var text = ""

    var body: some View {
        TextField(prompt, text: $text, prompt: Text(prompt))
            .labelsHidden()
            .textFieldStyle(.plain)
            #if os(iOS)
            .keyboardType(.numberPad)
            #endif
            .onAppear { text = value }
            .onChange(of: value) { text = value }
            .onChange(of: text) {
                let digits = SocietyNumber.digits(text, limit: limit)
                if digits != text { text = digits }
                if digits != value { value = digits }
            }
    }
}
