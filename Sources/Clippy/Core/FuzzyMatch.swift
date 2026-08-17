/// Scores how well a query matches a candidate string, in the shape of
/// `HotKeyCombo.parse` — pure and static, so its edge cases are testable
/// without AppKit or timers.
///
/// Greedy left-to-right subsequence matching with bonuses tuned so that
/// "sl" ranks Slack above Sublime Text: a whole-query prefix dominates, matches
/// at word starts and contiguous runs are rewarded, and skipped characters cost
/// more before the first match than between matches.
enum FuzzyMatch {
    /// nil = the query is not a subsequence of the candidate. Higher = better.
    /// An empty query scores 0 against everything, so ordering falls entirely
    /// to frecency.
    static func score(_ query: String, in candidate: String) -> Int? {
        let needle = query.map(lowered)
        guard !needle.isEmpty else { return 0 }

        let haystack = prepared(candidate)
        guard needle.count <= haystack.count else { return nil }

        var total = 0
        var searchFrom = 0
        var previousMatch: Int?

        for character in needle {
            var found: Int?
            var index = searchFrom
            while index < haystack.count {
                if haystack[index].char == character { found = index; break }
                index += 1
            }
            guard let matchIndex = found else { return nil }

            if let previous = previousMatch {
                let skipped = matchIndex - previous - 1
                if skipped == 0 { total += 10 } else { total -= skipped }
            } else {
                total -= 3 * matchIndex
            }
            if haystack[matchIndex].isWordStart { total += 15 }

            previousMatch = matchIndex
            searchFrom = matchIndex + 1
        }

        if haystack.prefix(needle.count).map(\.char) == needle {
            total += 100
        }
        return total
    }

    /// One pass over the candidate producing one index space. Lowercasing a
    /// string can change its character count (Turkish İ becomes two scalars),
    /// so a lowercased copy must never be indexed with an index derived from the
    /// original — that is an out-of-range crash, and this runs against arbitrary
    /// clipboard text on the keystroke path.
    ///
    /// `isWordStart` is index 0, or preceded by a separator, or a lower→upper
    /// transition — so "vsc" hits the capitals in "Visual Studio Code" and "qt"
    /// hits the T in "QuickTime".
    private static func prepared(_ candidate: String) -> [(char: Character, isWordStart: Bool)] {
        var result: [(char: Character, isWordStart: Bool)] = []
        result.reserveCapacity(candidate.count)
        var previous: Character?
        for character in candidate {
            let isWordStart: Bool
            if let previous {
                if previous == " " || previous == "-" || previous == "_"
                    || previous == "." || previous == "/" {
                    isWordStart = true
                } else {
                    isWordStart = previous.isLowercase && character.isUppercase
                }
            } else {
                isWordStart = true
            }
            result.append((lowered(character), isWordStart))
            previous = character
        }
        return result
    }

    /// Single-character lowercasing that cannot change the count.
    private static func lowered(_ character: Character) -> Character {
        character.lowercased().first ?? character
    }
}
