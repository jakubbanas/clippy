import Foundation

/// One group of launcher rows, with its header text.
struct LauncherSection: Equatable {
    let title: String
    let commands: [Command]

    /// `Command` holds a closure, so identity is compared by id — enough for
    /// tests and for the table's diffing.
    static func == (lhs: LauncherSection, rhs: LauncherSection) -> Bool {
        lhs.title == rhs.title && lhs.commands.map(\.id) == rhs.commands.map(\.id)
    }
}

/// Turns a query plus a flat command list into ordered, capped sections.
/// Pure — the window calls this on every keystroke and renders the result.
///
/// Scores are compared only *within* a section, because an 8-character app name
/// and a 2000-character clipboard clip do not share a scale. Section order is
/// dynamic (best member first), so the thing you actually typed stays on top.
enum LauncherRanking {
    static func sections(
        for query: String,
        commands: [Command],
        frecency: [String: FrecencyEntry],
        now: Date,
        maxPerSection: Int = 5
    ) -> [LauncherSection] {
        var scored: [String: [(command: Command, score: Int)]] = [:]
        for command in commands {
            // searchText, not title: a clipboard row's title is a 60-character
            // preview, and scoring that would drop any clip whose match sits
            // further in.
            guard let base = FuzzyMatch.score(query, in: command.searchText ?? command.title)
            else { continue }
            let score = base + Frecency.boost(frecency[command.id], now: now)
            scored[command.section, default: []].append((command, score))
        }

        // Built as explicit statements rather than one chain: the tuple-returning
        // map/sorted combination defeats Swift's type-checker.
        var ranked: [(section: LauncherSection, best: Int)] = []
        for (title, rows) in scored {
            let sorted = rows.sorted { left, right in
                left.score == right.score
                    ? left.command.title < right.command.title
                    : left.score > right.score
            }
            let capped: [Command] = Array(sorted.prefix(maxPerSection)).map { $0.command }
            let best: Int = sorted.first?.score ?? Int.min
            ranked.append((LauncherSection(title: title, commands: capped), best))
        }
        ranked.sort { left, right in
            left.best == right.best
                ? left.section.title < right.section.title
                : left.best > right.best
        }
        return ranked.map { $0.section }
    }
}
