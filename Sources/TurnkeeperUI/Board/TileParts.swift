import BattleCards
import Bestiary
import TurnkeeperKit
import SwiftUI

/// Small round condition magnets with their values. Tap to open the condition palette.
struct ConditionChips: View {
    let combatant: Combatant
    let edit: () -> Void

    var body: some View {
        Button(action: edit) {
            FlowLayout(spacing: 4) {
                ForEach(combatant.conditions) { condition in
                    Text(ConditionLabel.short(condition))
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ConditionLabel.color(condition).opacity(0.9), in: Capsule())
                        .overlay { Capsule().strokeBorder(.white.opacity(0.5)) }
                }
                if combatant.conditions.isEmpty {
                    Image(systemName: "plus.circle").font(.caption).opacity(0.6)
                }
            }
        }
        .buttonStyle(.plain)
        .help("Conditions")
    }
}

/// Long-press or right-click actions on a strip.
struct TileMenu: View {
    let controller: BoardController
    let combatant: Combatant
    @Binding var sheet: BoardSheet?
    @Environment(\.isCompactBoard) private var isCompact

    var body: some View {
        // In setup a tap chooses the strip for its initiative, so its card is here.
        if isCompact {
            Button("Show Card", systemImage: "rectangle.portrait") {
                controller.pinnedID = combatant.id
                sheet = .card
            }
        }
        Button("Conditions…", systemImage: "staroflife") { sheet = .conditions(combatant.id) }
        if combatant.tracksHitPoints {
            Button("Damage or Heal…", systemImage: "heart") { sheet = .hitPoints(combatant.id) }
        }
        Button("Initiative…", systemImage: "number") { sheet = .initiative(combatant.id) }
        if combatant.kind == .creature || combatant.kind == .hazard {
            Picker("Template", selection: templateBinding) {
                Text("Weak").tag(CreatureTemplate.weak)
                Text("Normal").tag(CreatureTemplate.normal)
                Text("Elite").tag(CreatureTemplate.elite)
            }
        }
        if combatant.kind == .creature {
            Picker("Side", selection: sideBinding) {
                Text("Enemy").tag(Side.enemy)
                Text("Ally").tag(Side.ally)
            }
        }
        Divider()
        if controller.state.phase == .active { TurnStatusButtons(controller: controller, combatant: combatant) }
        Button("Move to Bench", systemImage: "chair.lounge") { controller.change { $0.moveToBench(combatant.id) } }
        Button("Remove", systemImage: "trash", role: .destructive) { controller.change { $0.remove(combatant.id) } }
    }

    private var sideBinding: Binding<Side> {
        Binding(get: { combatant.side },
                set: { side in controller.change { $0[combatant.id]?.side = side } })
    }

    private var templateBinding: Binding<CreatureTemplate> {
        Binding(get: { combatant.template },
                set: { template in controller.change { $0.setTemplate(template, for: combatant.id) } })
    }
}

/// The strip menu's actions on a combatant's turns: delaying, dying and death.
private struct TurnStatusButtons: View {
    let controller: BoardController
    let combatant: Combatant

    var body: some View {
        if combatant.isDead {
            Button("Revive (Not Dead)", systemImage: "heart.fill") {
                controller.change { $0.revive(combatant.id) }
            }
        } else {
            delayButton
            Button("Dead", systemImage: "xmark.circle.fill") { controller.change { $0.markDead(combatant.id) } }
        }
        if combatant.isDying {
            Button("Stabilize (End Dying)", systemImage: "heart.text.square") {
                controller.change { $0.stabilize(combatant.id) }
            }
        } else {
            Button("Knocked Out (Dying)", systemImage: "heart.slash") {
                controller.change { $0.knockOut(combatant.id) }
            }
        }
    }

    @ViewBuilder
    private var delayButton: some View {
        if combatant.isDelaying {
            Button("Return from Delay", systemImage: "arrow.uturn.left") {
                controller.change { $0.endDelay(combatant.id) }
            }
        } else {
            Button("Delay", systemImage: "hourglass") { controller.startDelay(combatant.id) }
        }
    }
}
