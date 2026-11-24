import Foundation

/// Organized Play numbers as typed: digits only, cut to their length.
public enum SocietyNumber {
    /// An Organized Play ID has one to eight digits.
    public static let organizedPlayIDLength = 8
    /// A character number always has four digits.
    public static let characterNumberLength = 4

    public static func digits(_ text: String, limit: Int) -> String {
        String(text.filter { ("0"..."9").contains($0) }.prefix(limit))
    }
}

public extension Library {
    /// The parties a campaign shows: all in Society play, else the first. Hidden ones are kept, not deleted.
    func shownParties(in campaignID: UUID) -> [Party] {
        let parties = parties(in: campaignID)
        return isSociety(campaignID) ? parties : Array(parties.prefix(1))
    }

    /// Whether a campaign is Society play. One that can't be found counts as it, as libraries from before the
    /// setting do.
    func isSociety(_ campaignID: UUID?) -> Bool {
        campaigns.first { $0.id == campaignID && !$0.isDeleted }?.isSociety ?? true
    }

    /// What switching Society play off would hide in a campaign, a sentence each; empty when nothing would
    /// change. Nothing is deleted: switching it back on shows it all again.
    func effectsOfLeavingSociety(_ campaignID: UUID) -> [String] {
        hiddenPartiesEffect(campaignID) + scenarios(in: campaignID).compactMap(hiddenPlansEffect)
    }

    private func hiddenPartiesEffect(_ campaignID: UUID) -> [String] {
        let names = parties(in: campaignID).map { "“\($0.name)”" }
        guard let kept = names.first, names.count > 1 else { return [] }
        let noun = names.count > 2 ? "parties" : "party"
        return ["Hides the \(noun) \(Self.list(Array(names.dropFirst()))). \(kept) stays."]
    }

    /// The scenario's line, when encounters have plans at difficulties other than the one it would keep.
    private func hiddenPlansEffect(_ scenario: Scenario) -> String? {
        let kept = scenario.baseVariantLabel
        let affected = encounters(in: scenario.id).filter { encounter in
            encounter.variants.contains { $0.label != kept && !($0.slots.isEmpty && $0.events.isEmpty) }
        }
        guard !affected.isEmpty else { return nil }
        let names = Self.list(affected.map { "“\($0.name)”" })
        return "“\(scenario.name)” shows only its “\(kept)” difficulty, hiding other plans for \(names)."
    }

    /// "A, B and C", in English whatever the device's language, like the rest of the app.
    private static func list(_ items: [String]) -> String {
        items.formatted(.list(type: .and).locale(Locale(identifier: "en_US")))
    }
}
