import Foundation
import Testing
@testable import TurnkeeperKit

@Suite("Spoken names")
struct SpokenNameMatcherTests {
    private let valeros = UUID()
    private let bob = UUID()
    private let bobJones = UUID()
    private let zoe = UUID()

    private var matcher: SpokenNameMatcher {
        SpokenNameMatcher(candidates: [
            (valeros, ["Valeros", "Sam"]), (bob, ["Bob the Barbarian", "Bob"]), (bobJones, ["Bob Jones", "Alex"]),
            (zoe, ["Zoë", "Twenty Two"])
        ])
    }

    @Test("A player's or a character's name selects it, in any case")
    func names() {
        #expect(matcher.matches(in: "Sam") == [valeros])
        #expect(matcher.matches(in: "valeros seventeen") == [valeros])
        #expect(matcher.matches(in: "ALEX") == [bobJones])
    }

    @Test("A word of a character's name is enough, but not a short joining word")
    func firstWord() {
        #expect(matcher.matches(in: "barbarian") == [bob])
        #expect(matcher.matches(in: "the") == [])
    }

    @Test("A name two candidates share gives both, in candidate order")
    func shared() {
        #expect(matcher.matches(in: "Bob") == [bob, bobJones])
    }

    @Test("The longest name wins")
    func longest() {
        #expect(matcher.matches(in: "Bob Jones") == [bobJones])
        #expect(matcher.matches(in: "Bob the Barbarian") == [bob])
    }

    @Test("Accents don't matter")
    func diacritics() {
        #expect(matcher.matches(in: "Zoe") == [zoe])
        let renee = UUID()
        #expect(SpokenNameMatcher(candidates: [(renee, ["Renee"])]).matches(in: "Renée") == [renee])
    }

    @Test("The last name heard wins")
    func lastWins() {
        #expect(matcher.matches(in: "Sam, no, Alex") == [bobJones])
    }

    @Test("Number words and short words aren't names")
    func numbers() {
        #expect(matcher.matches(in: "twenty two") == [zoe], "the whole name still matches")
        #expect(matcher.matches(in: "twenty") == [])
        #expect(SpokenNameMatcher(candidates: [(UUID(), ["Al"])]).matches(in: "Al") == [])
        #expect(matcher.matches(in: "") == [])
    }

    @Test("Nat before a number is a natural roll, not a player called Nat")
    func natIsNotAName() {
        let nat = UUID()
        let matcher = SpokenNameMatcher(candidates: [(nat, ["Nat"]), (UUID(), ["Nan"])])
        #expect(matcher.matches(in: "nat 20") == [])
        #expect(matcher.matches(in: "natural twenty") == [])
        #expect(matcher.matches(in: "Nat") == [nat])
        #expect(matcher.matches(in: "Nan").count == 1, "Nan is a name, not a number")
    }
}
