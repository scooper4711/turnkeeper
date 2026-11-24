import Foundation

/// Finds who a transcript names, for choosing a row on the voice initiative screen: "Sam", "Valeros", or
/// "Bob" for "Bob the Barbarian". Whole words only, ignoring case and accents.
///
/// The last name heard wins, and of the names ending there the longest wins, so "Bob Jones" means only Bob
/// Jones even when another player is called Bob. A name two candidates share gives both; choosing between
/// them is up to the caller (see `InitiativeRoster.pick(_:)`).
public struct SpokenNameMatcher: Sendable {
    /// One way of saying a candidate: a whole name or one of its words, as folded words.
    private struct Phrase: Sendable {
        var id: UUID
        var words: [String]
    }

    /// A phrase found in the transcript.
    private struct Match {
        var id: UUID
        var end: Int
        var length: Int
    }

    /// Short joining words in names, such as "the" in "Bob the Barbarian", which would match far too often.
    private static let joiningWords: Set<String> = ["the", "and", "of", "von", "van", "der", "del", "les"]

    private let phrases: [Phrase]
    private let order: [UUID]

    public init(candidates: [(id: UUID, names: [String])]) {
        order = candidates.map(\.id)
        phrases = candidates.flatMap { candidate in
            candidate.names.flatMap { Self.phrases(for: $0, id: candidate.id) }
        }
    }

    /// Every candidate the last name heard could mean, in candidate order; empty when no name was heard.
    public func matches(in transcript: String) -> [UUID] {
        let words = Self.words(transcript)
        let found = phrases.flatMap { Self.matches(of: $0, in: words) }
        guard let best = found.max(by: { ($0.end, $0.length) < ($1.end, $1.length) }) else { return [] }
        let ids = Set(found.filter { $0.end == best.end && $0.length == best.length }.map(\.id))
        return order.filter(ids.contains)
    }

    private static func phrases(for name: String, id: UUID) -> [Phrase] {
        let words = words(name)
        let singles = words.filter(isNameWord).map { Phrase(id: id, words: [$0]) }
        return words.count > 1 ? [Phrase(id: id, words: words)] + singles : singles
    }

    /// Words long enough to be a name on their own: three letters or more, and not a number or joining word.
    private static func isNameWord(_ word: String) -> Bool {
        word.count >= 3 && !joiningWords.contains(word) && !SpokenNumberParser.isNumberWord(word)
    }

    private static func matches(of phrase: Phrase, in words: [String]) -> [Match] {
        let length = phrase.words.count
        guard length <= words.count else { return [] }
        return (0...(words.count - length)).compactMap { start in
            Array(words[start..<(start + length)]) == phrase.words
                ? Match(id: phrase.id, end: start + length - 1, length: length) : nil
        }
    }

    /// Lowercased words without accents, split at anything that isn't a letter or a digit.
    static func words(_ text: String) -> [String] {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }
}
