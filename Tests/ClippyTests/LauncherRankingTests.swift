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
            command("app:slack", "Slack", CommandSection.applications),
            command("app:safari", "Safari", CommandSection.applications),
            command("app:mail", "Mail", CommandSection.applications),
        ]
    }

    func testSectionsAreOrderedByBestMemberScore() {
        let sections = LauncherRanking.sections(
            for: "sl", commands: fixture, frecency: [:], now: now
        )
        // "Slack" wins on a whole-query prefix; "Start focus" only has a late,
        // scattered s/l. Applications therefore leads outright, not by a tiebreak.
        XCTAssertEqual(sections.first?.title, CommandSection.applications)
        XCTAssertEqual(sections.first?.commands.first?.id, "app:slack")
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

    /// A calculator row shows its result but must match on the typed
    /// expression. Scoring `title` instead of `searchText` would drop it.
    func testMatchesAgainstSearchTextNotTitle() {
        let row = Command(
            id: "calculator:result",
            title: "2",
            searchText: "1+1",
            section: CommandSection.commands,
            perform: {}
        )
        let sections = LauncherRanking.sections(
            for: "1+1", commands: [row], frecency: [:], now: now
        )
        XCTAssertEqual(sections.first?.commands.first?.id, "calculator:result")
    }

    func testEmptyQueryKeepsEveryCommandGroupedBySection() {
        let sections = LauncherRanking.sections(
            for: "", commands: fixture, frecency: [:], now: now
        )
        XCTAssertEqual(Set(sections.map(\.title)), [
            CommandSection.commands, CommandSection.applications,
        ])
    }

    /// Every row scores 0 on an empty query, so section order comes entirely
    /// from the declared priority — not from the titles, which would put
    /// Applications above Commands and Top Apps last.
    func testEmptyQueryOrdersSectionsByPriorityNotAlphabetically() {
        let commands = fixture + [command("app:top", "Slack", CommandSection.topApps)]
        let sections = LauncherRanking.sections(
            for: "", commands: commands, frecency: [:], now: now
        )
        XCTAssertEqual(sections.map(\.title), [
            CommandSection.topApps,
            CommandSection.commands,
            CommandSection.applications,
        ])
    }

    /// Priority is only a tie-break: a better match still wins the top slot.
    func testScoreStillBeatsSectionPriority() {
        let commands = [
            command("app:top", "Zebra", CommandSection.topApps),
            command("app:mail", "Mail", CommandSection.applications),
        ]
        let sections = LauncherRanking.sections(
            for: "mail", commands: commands, frecency: [:], now: now
        )
        XCTAssertEqual(sections.map(\.title), [CommandSection.applications])
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
