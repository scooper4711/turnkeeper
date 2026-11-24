import Foundation

/// Turns speech transcripts into initiative numbers: "seventeen", "twenty-three", "17", "minus one",
/// "17 and a half". The last number heard wins, so "fourteen, no, sixteen" gives 16.
///
/// The voice screen hears the whole table, so table talk mustn't read as a number: "oh" isn't zero, and "one" is a
/// number only where it can't be the pronoun ("which one", "one more").
public enum SpokenNumberParser {
    /// The last number in the transcript, or nil when there is none.
    public static func initiative(from transcript: String) -> Double? {
        spokenInitiative(from: transcript)?.value
    }

    /// The last number in the transcript, and whether "nat", "natural" or "natty" came just before it, as in
    /// "nat 17". Nil when there is no number.
    public static func spokenInitiative(from transcript: String) -> SpokenInitiative? {
        let words = words(transcript)
        guard let last = numbers(in: words).last else { return nil }
        let start = last.range.lowerBound
        let isNatural = start > 0 && naturals.contains(words[start - 1])
        return SpokenInitiative(value: last.value, isNatural: isNatural)
    }

    /// Whether a word is part of a number, such as "twenty" or "17", so name matching can skip it.
    public static func isNumberWord(_ word: String) -> Bool {
        let word = word.lowercased()
        return digits(word) != nil || units[word] != nil || tens[word] != nil || negatives.contains(word)
    }

    /// Whether a word marks a natural roll, as "nat" does in "nat 17".
    public static func isNaturalWord(_ word: String) -> Bool {
        naturals.contains(word.lowercased())
    }

    private static let units = [
        "zero": 0, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7,
        "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14,
        "fifteen": 15, "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19
    ]
    private static let tens = [
        "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50, "sixty": 60, "seventy": 70, "eighty": 80, "ninety": 90
    ]
    private static let negatives: Set<String> = ["minus", "negative"]
    private static let naturals: Set<String> = ["nat", "natural", "natty"]
    /// Words before "one" that make it the pronoun, as in "which one".
    private static let pronounLeads: Set<String> = [
        "which", "that", "this", "the", "a", "any", "each", "every", "no", "another", "other", "last", "next", "first",
        "good", "nice", "big", "little", "bad", "right", "wrong", "new", "old", "same"
    ]
    /// Words after a number that may still belong to it, as in "one and a half".
    private static let numberTails: Set<String> = ["and", "point"]

    private struct SpokenNumber {
        var value: Double
        /// The words the number used.
        var range: Range<Int>
    }

    private static func words(_ transcript: String) -> [String] {
        transcript.lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".")).inverted)
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ".")) }
            .filter { !$0.isEmpty }
    }

    private static func numbers(in words: [String]) -> [SpokenNumber] {
        var found: [SpokenNumber] = []
        var index = 0
        while index < words.count {
            guard let (value, end) = number(at: index, in: words) else {
                index += 1
                continue
            }
            let isNegative = index > 0 && negatives.contains(words[index - 1])
            let (fraction, fractionEnd) = half(after: end, in: words)
            let start = isNegative ? index - 1 : index
            found.append(SpokenNumber(value: (isNegative ? -value : value) + fraction, range: start..<fractionEnd))
            index = fractionEnd
        }
        return found
    }

    /// A number starting at `index`: digits, a unit word, or a tens word optionally followed by a unit.
    private static func number(at index: Int, in words: [String]) -> (Double, Int)? {
        let word = words[index]
        if let value = digits(word) { return (value, index + 1) }
        if word == "one", isPronoun(at: index, in: words) { return nil }
        if let value = units[word] { return (Double(value), index + 1) }
        guard let ten = tens[word] else { return nil }
        if index + 1 < words.count, let unit = units[words[index + 1]], unit < 10 {
            return (Double(ten + unit), index + 2)
        }
        return (Double(ten), index + 1)
    }

    /// A number written in digits, such as "17" or "17.5"; not "nan" or "infinity", which `Double` also reads.
    private static func digits(_ word: String) -> Double? {
        guard word.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == ".") }) else { return nil }
        return Double(word)
    }

    /// "one" as in "which one" or "one more", rather than the number.
    private static func isPronoun(at index: Int, in words: [String]) -> Bool {
        let follows = index > 0 && pronounLeads.contains(words[index - 1])
        let leads = index + 1 < words.count && !numberTails.contains(words[index + 1])
        return follows || leads
    }

    /// "and a half" or "point five" after a number, used to break ties.
    private static func half(after index: Int, in words: [String]) -> (Double, Int) {
        let rest = Array(words[index...].prefix(3))
        if rest.starts(with: ["and", "a", "half"]) { return (0.5, index + 3) }
        if rest.starts(with: ["point", "five"]) || rest.starts(with: ["point", "5"]) { return (0.5, index + 2) }
        return (0, index)
    }
}

/// A spoken initiative: the number, and whether it was a natural roll ("nat 17") that needs the modifier added.
public struct SpokenInitiative: Sendable, Hashable {
    public var value: Double
    public var isNatural: Bool

    public init(value: Double, isNatural: Bool) {
        self.value = value
        self.isNatural = isNatural
    }
}
