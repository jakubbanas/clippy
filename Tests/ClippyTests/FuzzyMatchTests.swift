import XCTest
@testable import Clippy

final class FuzzyMatchTests: XCTestCase {
    /// Exact totals, hand-derived from the scoring table. These pin the weights:
    /// if you change a bonus, this test is supposed to fail.
    func testExactScores() {
        // "Slack": s@0 word-start +15, l@1 contiguous +10, whole-query prefix +100.
        XCTAssertEqual(FuzzyMatch.score("sl", in: "Slack"), 125)
        // "Sublime Text": s@0 +15, l@3 skips 2 → −2, no prefix ("su" ≠ "sl").
        XCTAssertEqual(FuzzyMatch.score("sl", in: "Sublime Text"), 13)
        // "Terminal": all four contiguous from index 0, plus prefix.
        XCTAssertEqual(FuzzyMatch.score("term", in: "Terminal"), 145)
    }

    /// The case this whole design exists to get right: two real apps that both
    /// start with S, where the one you meant must win.
    func testSlRanksSlackAboveSublimeText() {
        let slack = FuzzyMatch.score("sl", in: "Slack")
        let sublime = FuzzyMatch.score("sl", in: "Sublime Text")
        XCTAssertNotNil(slack)
        XCTAssertNotNil(sublime)
        XCTAssertGreaterThan(slack!, sublime!)
    }

    func testExactPrefixBeatsMidWordMatch() {
        let prefix = FuzzyMatch.score("mail", in: "Mail")
        let midWord = FuzzyMatch.score("mail", in: "Gmail Notifier")
        XCTAssertNotNil(midWord)
        XCTAssertGreaterThan(prefix!, midWord!)
    }

    func testAcronymMatchesWordStarts() {
        XCTAssertNotNil(FuzzyMatch.score("vsc", in: "Visual Studio Code"))
    }

    /// Lower→upper counts as a word start, so "qt" finds QuickTime's T and beats
    /// a candidate where the t is mid-word.
    func testCamelCaseWordStartBeatsMidWord() {
        let camel = FuzzyMatch.score("qt", in: "QuickTime Player")
        let midWord = FuzzyMatch.score("qt", in: "Quit Terminal")
        XCTAssertNotNil(camel)
        XCTAssertNotNil(midWord)
        XCTAssertGreaterThan(camel!, midWord!)
    }

    func testNonSubsequenceReturnsNil() {
        XCTAssertNil(FuzzyMatch.score("xyz", in: "Slack"))
        // "Safari" has no L at all — a near-miss must still be nil, not 0.
        XCTAssertNil(FuzzyMatch.score("sl", in: "Safari"))
    }

    func testMissingLastCharacterReturnsNil() {
        XCTAssertNil(FuzzyMatch.score("slackk", in: "Slack"))
    }

    func testEmptyQueryScoresZeroForEverything() {
        XCTAssertEqual(FuzzyMatch.score("", in: "Slack"), 0)
        XCTAssertEqual(FuzzyMatch.score("", in: "Some very long clip of text"), 0)
    }

    func testCaseInsensitive() {
        XCTAssertEqual(FuzzyMatch.score("SLACK", in: "slack"), FuzzyMatch.score("slack", in: "Slack"))
    }

    /// Runs against arbitrary clipboard text on the keystroke path, so a
    /// character whose lowercase form has a different scalar count must not
    /// crash or misindex.
    func testSurvivesAwkwardUnicode() {
        XCTAssertNotNil(FuzzyMatch.score("st", in: "İstanbul"))
        XCTAssertNil(FuzzyMatch.score("q", in: "İstanbul ﬁre 👨‍👩‍👧 ß"))
        XCTAssertNotNil(FuzzyMatch.score("st", in: "ẛ̣ street ß text"))
        // Documented limitation, not a crash: lowercased "İ" is i + a combining
        // dot, which stays one grapheme cluster and so does not equal bare "i".
        XCTAssertNil(FuzzyMatch.score("i", in: "İstanbul"))
    }

    func testContiguousBeatsGappy() {
        let contiguous = FuzzyMatch.score("term", in: "Terminal")
        let gappy = FuzzyMatch.score("term", in: "The Rambling Mixer")
        XCTAssertNotNil(gappy)
        XCTAssertGreaterThan(contiguous!, gappy!)
    }
}
