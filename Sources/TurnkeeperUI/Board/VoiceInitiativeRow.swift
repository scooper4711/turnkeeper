import TurnkeeperKit
import SwiftUI

/// One row of the voice initiative screen: the initiative, the name and the player. The selected row is larger
/// and outlined in yellow, and a selected creature shows its initiative modifiers. After a natural 20 the row
/// sparkles for a moment.
struct VoiceInitiativeRow: View {
    let combatant: Combatant
    let isSelected: Bool
    let isSparkling: Bool
    /// Shown while a creature's row is selected; empty for PCs.
    let skills: [InitiativeSkill]
    @AppStorage(PlayerNamesToggle.key) private var showsPlayerNames = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Circle().fill(combatant.magnet.color.gradient).frame(width: 14, height: 14)
                Text(combatant.initiative.map(InitiativeText.format) ?? "–")
                    .font((isSelected ? Font.title : .title3).monospacedDigit().bold())
                    // One width for every row, so the names line up whichever row is selected.
                    .frame(width: 64, alignment: .trailing)
                    .contentTransition(.numericText())
                nameText.font(isSelected ? .title2 : .title3).lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }
            if isSelected && !skills.isEmpty { InitiativeSkillsView(skills: skills, size: 17).padding(.leading, 26) }
        }
        .padding(.vertical, isSelected ? 14 : 6)
        .padding(.horizontal, 8)
        .frame(minHeight: isSelected ? 62 : 46)
        .contentShape(Rectangle())
        .overlay {
            if isSelected { RoundedRectangle(cornerRadius: 10).stroke(.yellow, lineWidth: 3) }
        }
        .overlay(alignment: .trailing) { if isSparkling { Sparkle() } }
        .animation(.snappy, value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("voiceRow.\(combatant.name)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// "Valeros (Sam)", with the player's name softer, when player names are shown and the PC has one.
    private var nameText: Text {
        guard showsPlayerNames, !combatant.playerName.isEmpty else { return Text(combatant.name).bold() }
        return Text(combatant.name).bold() + Text(" (\(combatant.playerName))").foregroundStyle(.secondary)
    }
}

/// A natural 20: sparkles with a gold glow.
private struct Sparkle: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: "sparkles")
            .font(.title)
            .foregroundStyle(.yellow)
            .shadow(color: .orange, radius: 8)
            .symbolEffect(.bounce, options: reduceMotion ? .nonRepeating : .repeat(2), isActive: true)
            .padding(.trailing, 12)
            .accessibilityLabel("Natural 20")
            .transition(.scale.combined(with: .opacity))
    }
}
