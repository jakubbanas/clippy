import XCTest
@testable import Clippy

final class ClipboardSearchTests: XCTestCase {
    private func clip(_ text: String, at time: Double = 1_755_432_000) -> Clip {
        Clip(copiedAt: time, app: "Slack", text: text)
    }

    func testEmptyQueryReturnsEverything() {
        let clips = [clip("one"), clip("two", at: 1), clip("three", at: 2)]
        XCTAssertEqual(ClipboardSearch.filter(clips, query: ""), clips)
    }

    func testWhitespaceOnlyQueryReturnsEverything() {
        let clips = [clip("one"), clip("two", at: 1)]
        XCTAssertEqual(ClipboardSearch.filter(clips, query: "   "), clips)
    }

    func testMatchesSubstringAnywhereNotJustAtTheStart() {
        let clips = [clip("git rebase -i HEAD~3"), clip("brew install jq", at: 1)]
        XCTAssertEqual(ClipboardSearch.filter(clips, query: "rebase").map(\.text), ["git rebase -i HEAD~3"])
    }

    func testMatchIsCaseInsensitive() {
        XCTAssertEqual(ClipboardSearch.filter([clip("SELECT * FROM users")], query: "select").count, 1)
    }

    func testMatchIgnoresDiacritics() {
        XCTAssertEqual(ClipboardSearch.filter([clip("Kraków")], query: "krakow").count, 1)
    }

    /// The bug this whole feature exists to fix: `FuzzyMatch` only saw the first
    /// 200 characters of a clip, so a word further in was unfindable.
    func testMatchesTextBeyondCharacter200() {
        let text = String(repeating: "x", count: 500) + "needle"
        XCTAssertEqual(ClipboardSearch.filter([clip(text)], query: "needle").count, 1)
    }

    /// Every term must match, in any order — this is what makes "git reb" work
    /// while staying a substring match rather than a subsequence one.
    func testAllTermsMustMatchInAnyOrder() {
        let clips = [
            clip("git rebase -i HEAD~3"),
            clip("git status", at: 1),
            clip("svn rebase", at: 2),
        ]
        XCTAssertEqual(ClipboardSearch.filter(clips, query: "reb git").map(\.text), ["git rebase -i HEAD~3"])
    }

    func testNonSubstringQueryMatchesNothing() {
        // "gtrb" is a subsequence of "git rebase" — FuzzyMatch would have kept it.
        XCTAssertTrue(ClipboardSearch.filter([clip("git rebase")], query: "gtrb").isEmpty)
    }

    func testPreservesInputOrder() {
        let clips = [clip("alpha match"), clip("beta match", at: 1), clip("gamma match", at: 2)]
        XCTAssertEqual(
            ClipboardSearch.filter(clips, query: "match").map(\.text),
            ["alpha match", "beta match", "gamma match"]
        )
    }
}
