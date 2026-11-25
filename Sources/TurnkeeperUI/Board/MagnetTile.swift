import BattleCards
import Bestiary
import TurnkeeperKit
import SwiftUI

/// One combatant's magnet: initiative, token, name, HP and condition chips, in the
/// magnet's color. Tap to show its card (and, in setup, to enter its initiative), long-press for its menu, drag
/// to reorder once combat has begun.
struct MagnetTile: View {
    let controller: BoardController
    let combatant: Combatant
    @Binding var sheet: BoardSheet?
    @AppStorage(PlayerNamesToggle.key) private var showsPlayerNames = true
    /// With the ladder alone, a tap on a strip opens its card in a sheet.
    @Environment(\.isCompactBoard) private var isCompact

    private var isCurrent: Bool { controller.state.currentID == combatant.id }
    private var isSetup: Bool { controller.state.phase == .setup }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: statusSymbol)
                .foregroundStyle(.yellow)
                .opacity(isCurrent || combatant.isDelaying || combatant.isDead ? 1 : 0)
                .frame(width: 16)
                .accessibilityLabel(combatant.isDead ? "Dead" : combatant.isDelaying ? "Delaying" : "")
            initiativeBadge
            ArtImage(path: tileArt, size: 46, shape: .circle, alignment: .top)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    nameText.font(.headline).lineLimit(2).minimumScaleFactor(0.8)
                    if combatant.template != .normal {
                        TemplateBadge(template: combatant.template, color: .black).fixedSize()
                    }
                }
                if isSetup && combatant.initiative == nil, let hint = modifierHint {
                    Text(hint).font(.caption.bold()).opacity(0.85)
                }
                ConditionChips(combatant: combatant) { sheet = .conditions(combatant.id) }
            }
            Spacer(minLength: 4)
            if combatant.tracksHitPoints {
                hitPoints
            } else if let armorClass {
                ArmorClassText(value: armorClass)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .foregroundStyle(.white)
        .background(background)
        .overlay {
            if isMissingInitiative { RoundedRectangle(cornerRadius: 10).stroke(.orange, style: missingStyle) }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            controller.pinnedID = combatant.id
            if isSetup {
                sheet = .initiative(combatant.id)
            } else if isCompact {
                sheet = .card
            }
        }
        .contextMenu { TileMenu(controller: controller, combatant: combatant, sheet: $sheet) }
        .modifier(DraggableUnlessSetup(id: combatant.id, isSetup: isSetup))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
        .accessibilityValue(accessibilityValue)
    }

    /// What VoiceOver reads after the strip's name: its conditions, such as "Dying 1, Unconscious", which the
    /// strip's chips show as a button of their own.
    private var accessibilityValue: String {
        combatant.conditions.map(ConditionLabel.short).joined(separator: ", ")
    }

    /// The mark at the strip's left: dead, delaying, or the arrow of the current turn.
    private var statusSymbol: String {
        if combatant.isDead { return "xmark" }
        return combatant.isDelaying ? "hourglass" : "arrowtriangle.right.fill"
    }

    /// "Valeros (Sam)", with the player's name softer, when player names are shown and the PC has one.
    private var nameText: Text {
        guard showsPlayerNames, !combatant.playerName.isEmpty else { return Text(combatant.name) }
        return Text(combatant.name) + Text(" (\(combatant.playerName))").fontWeight(.regular)
    }

    /// PC strips stay plain, even when a linked sheet has a portrait.
    private var tileArt: String {
        combatant.kind == .playerCharacter ? "" : controller.entry(for: combatant)?.art.thumbnail ?? ""
    }

    /// Outlined after Begin Combat's "Go Back", or while a creature that joined mid-fight still needs one.
    private var isMissingInitiative: Bool {
        combatant.initiative == nil && combatant.place == .ladder
            && (controller.highlightsMissingInitiative || controller.state.phase == .active)
    }

    private var missingStyle: StrokeStyle { StrokeStyle(lineWidth: 3, dash: [8, 5]) }

    /// "Perc +7 · Stealth +9": what to add to the die, for the GM's math.
    private var modifierHint: String? {
        let skills = controller.initiativeSkills(for: combatant).prefix(2)
        guard !skills.isEmpty else { return nil }
        return skills.map { "\($0.name == "Perception" ? "Perc" : $0.name) \(signed($0.modifier))" }
            .joined(separator: " · ")
    }

    private var initiativeBadge: some View {
        Button { sheet = .initiative(combatant.id) } label: {
            Text(combatant.initiative.map(InitiativeText.format) ?? "–")
                .font(.title3.monospacedDigit().bold())
                .frame(minWidth: 40)
                .padding(.vertical, 4)
                .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help("Initiative")
    }

    private var armorClass: AdjustedValue? { controller.armorClass(of: combatant) }

    private var hitPoints: some View {
        let maximum = max(controller.maxHitPoints(of: combatant), 1)
        let current = max(maximum - combatant.damageTaken, 0)
        return Button { sheet = .hitPoints(combatant.id) } label: {
            VStack(alignment: .trailing, spacing: 3) {
                let temporary = combatant.temporaryHitPoints > 0 ? " +\(combatant.temporaryHitPoints)" : ""
                let fraction = Text("\(current)/\(maximum)\(temporary)").lineLimit(1).fixedSize()
                // Numbers never break; on a narrow strip AC sits above the hit points instead (#101).
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        if let armorClass { ArmorClassText(value: armorClass) }
                        fraction
                    }
                    VStack(alignment: .trailing, spacing: 2) {
                        if let armorClass { ArmorClassText(value: armorClass) }
                        fraction
                    }
                }
                .font(.callout.monospacedDigit().bold())
                ProgressView(value: Double(current), total: Double(maximum))
                    .tint(current * 4 <= maximum ? .red : .green)
                    .frame(width: 80)
            }
        }
        .buttonStyle(.plain)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(combatant.magnet.color.gradient)
            .overlay {
                if let border = combatant.template.borderColor {
                    RoundedRectangle(cornerRadius: 10).strokeBorder(border, lineWidth: 4)
                }
            }
            .overlay {
                if isCurrent { RoundedRectangle(cornerRadius: 10).stroke(.yellow, lineWidth: 2) }
            }
            .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
    }
}

enum InitiativeText {
    /// "17", or "17½" for a tie-breaking half.
    static func format(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : "\(Int(value.rounded(.down)))½"
    }
}

/// "AC 16" on a strip, in yellow when the template or a condition changes it.
private struct ArmorClassText: View {
    let value: AdjustedValue

    var body: some View {
        (Text("AC ").font(.caption.bold()) + Text("\(value.value)"))
            .font(.callout.monospacedDigit().bold())
            .foregroundStyle(value.isChanged ? .yellow : .white)
            .lineLimit(1)
            .fixedSize()
            .accessibilityLabel("Armor Class \(value.value)")
    }
}

/// Lets strips be dragged to reorder once combat has begun; during setup the order follows the numbers.
private struct DraggableUnlessSetup: ViewModifier {
    let id: UUID
    let isSetup: Bool

    func body(content: Content) -> some View {
        if isSetup { content } else { content.draggable(id.uuidString) }
    }
}
