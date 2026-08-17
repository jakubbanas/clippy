import XCTest
@testable import Clippy

final class LauncherRankingTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_755_432_000)

    private func command(_ id: String, _ title: String, _ section: String) -> Command {
        Command(id: id, title: title, section: section, perform: {})
    }

    private var fixture: [Command] {
        [
            command("focus:start", "Start focus", CommandSection.commands),
            command("clip:1", "the link to slack", CommandSection.clipboard),
            command("app:slack", "Slack", CommandSection.applications),
            command("app:safari", "Safari", CommandSection.applications),
            command("app:mail", "Mail", CommandSection.applications),
        ]
    }

    func testSectionsAreOrderedByBestMemberScore() {
        let sections = LauncherRanking.sections(
            for: "sl", commands: fixture, frecency: [:], now: now
        )
        // "Slack" wins on a whole-query prefix; the clip's late s/l pair scores
        // far lower. Applications therefore leads outright, not by a tiebreak.
        XCTAssertEqual(sections.first?.title, CommandSection.applications)
        XCTAssertEqual(sections.first?.commands.first?.id, "app:slack")
    }

    func testQueryMatchingOnlyAClipPutsClipboardFirst() {
        let sections = LauncherRanking.sections(
            for: "link", commands: fixture, frecency: [:], now: now
        )
        XCTAssertEqual(sections.first?.title, CommandSection.clipboard)
    }

    func testNonMatchesAreDropped() {
        let sections = LauncherRanking.sections(
            for: "safari", commands: fixture, frecency: [:], now: now
        )
        let ids = sections.flatMap { $0.commands.map(\.id) }
        XCTAssertEqual(ids, ["app:safari"])
    }

    func testNoMatchesReturnsEmpty() {
        XCTAssertTrue(
            LauncherRanking.sections(for: "zzzz", commands: fixture, frecency: [:], now: now).isEmpty
        )
    }

    func testEachSectionIsCapped() {
        let apps = (0..<12).map { command("app:\($0)", "App Number \($0)", CommandSection.applications) }
        let sections = LauncherRanking.sections(
            for: "app", commands: apps, frecency: [:], now: now, maxPerSection: 5
        )
        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].commands.count, 5)
    }

    func testFrecencyReordersWithinASection() {
        // "a" matches Mail (a@1), Safari (a@1) and Slack (a@2), so Mail wins on
        // merit — but heavy recent use of Slack must flip it.
        let plain = LauncherRanking.sections(
            for: "a", commands: fixture, frecency: [:], now: now
        )
        let boosted = LauncherRanking.sections(
            for: "a",
            commands: fixture,
            frecency: ["app:slack": FrecencyEntry(uses: 10, lastUsed: now.timeIntervalSince1970 - 60)],
            now: now
        )
        XCTAssertEqual(plain.first?.title, CommandSection.applications)
        XCTAssertEqual(plain.first?.commands.first?.id, "app:mail")
        XCTAssertEqual(boosted.first?.title, CommandSection.applications)
        XCTAssertEqual(boosted.first?.commands.first?.id, "app:slack")
    }

    func testFrecencyNeverResurrectsANonMatch() {
        let sections = LauncherRanking.sections(
            for: "safari",
            commands: fixture,
            frecency: ["app:slack": FrecencyEntry(uses: 10, lastUsed: now.timeIntervalSince1970)],
            now: now
        )
        XCTAssertFalse(sections.flatMap { $0.commands.map(\.id) }.contains("app:slack"))
    }

    /// A clipboard row shows a 60-character preview but must match on its full
    /// text. Scoring `title` instead of `searchText` would silently drop this.
    func testMatchesAgainstSearchTextNotTitle() {
        let buried = String(repeating: "filler ", count: 25) + "needle"
        let row = Command(
            id: "clip:1",
            title: "filler filler filler…",
            searchText: buried,
            section: CommandSection.clipboard,
            perform: {}
        )
        let sections = LauncherRanking.sections(
            for: "needle", commands: [row], frecency: [:], now: now
        )
        XCTAssertEqual(sections.first?.commands.first?.id, "clip:1")
    }

    func testEmptyQueryKeepsEveryCommandGroupedBySection() {
        let sections = LauncherRanking.sections(
            for: "", commands: fixture, frecency: [:], now: now
        )
        XCTAssertEqual(Set(sections.map(\.title)), [
            CommandSection.commands, CommandSection.applications, CommandSection.clipboard,
        ])
    }

    /// Same shape, same score — so ordering must come from the title, not from
    /// dictionary iteration order.
    func testTiesBreakAlphabeticallyForDeterminism() {
        let commands = [
            command("a", "Zebra Thing", CommandSection.applications),
            command("b", "Alpha Thing", CommandSection.applications),
        ]
        let sections = LauncherRanking.sections(
            for: "thing", commands: commands, frecency: [:], now: now
        )
        XCTAssertEqual(sections[0].commands.map(\.title), ["Alpha Thing", "Zebra Thing"])
    }
}
