import Bestiary
import Foundation

/// Which missing PDFs matter to the GM (R2.3a): those a creature needs for its art. A PDF can hold a pawn no creature
/// in the bestiary is named for, and art nothing can show is no reason for a warning.
public enum CreatureArtNeeds {
    /// The titles of the PDFs that `creatures` need because they have no other art.
    public static func sourceTitles(
        of creatures: [BestiaryIndexEntry], matcher: LibraryArtMatcher, customArtSubjects: Set<String>
    ) -> Set<String> {
        var titles: Set<String> = []
        for creature in creatures where !creature.art.hasArt && !customArtSubjects.contains(creature.key) {
            titles.formUnion(matcher.art(forCreatureNamed: creature.name, game: creature.game,
                                         isRemastered: creature.source.isRemastered).missingSources)
        }
        return titles
    }
}
