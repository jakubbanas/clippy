import Foundation

/// How often and how recently a launcher row was picked.
struct FrecencyEntry: Codable, Equatable {
    var uses: Int
    /// `timeIntervalSince1970`, so the JSON stays human-readable and stable.
    var lastUsed: Double
}

/// Usage-based ranking for launcher rows. Pure scoring plus isolated disk I/O,
/// so ordering is testable without touching the filesystem or the clock.
///
/// This is what makes the launcher a Raycast replacement rather than a list:
/// fuzzy score alone cannot know that you open Slack forty times a day.
enum Frecency {
    static var url: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.jbanas.clippy/launcher-frecency.json")
    }

    /// Added to a row's fuzzy score. Capped by use count and decayed by age, so
    /// a long-abandoned favourite cannot outrank what you used a minute ago.
    /// Never negative — an unknown row is simply unboosted.
    static func boost(_ entry: FrecencyEntry?, now: Date) -> Int {
        guard let entry else { return 0 }
        let age = now.timeIntervalSince1970 - entry.lastUsed
        let multiplier: Int
        switch age {
        case ..<3_600: multiplier = 10
        case ..<86_400: multiplier = 6
        case ..<604_800: multiplier = 3
        case ..<2_592_000: multiplier = 1
        default: multiplier = 0
        }
        return min(entry.uses, 10) * multiplier
    }

    /// Ids by use count descending — the "top apps" list for the empty-query
    /// first view. Recency breaks ties, then the id itself, so the order is
    /// deterministic. Unlike `boost`, this deliberately ignores decay: these are
    /// the apps you use most, not the ones you touched last.
    static func topUsed(_ store: [String: FrecencyEntry], limit: Int) -> [String] {
        let sorted = store.sorted { left, right in
            if left.value.uses != right.value.uses { return left.value.uses > right.value.uses }
            if left.value.lastUsed != right.value.lastUsed { return left.value.lastUsed > right.value.lastUsed }
            return left.key < right.key
        }
        return sorted.prefix(limit).map { $0.key }
    }

    static func record(
        _ store: [String: FrecencyEntry],
        id: String,
        now: Date
    ) -> [String: FrecencyEntry] {
        var store = store
        let uses = (store[id]?.uses ?? 0) + 1
        store[id] = FrecencyEntry(uses: uses, lastUsed: now.timeIntervalSince1970)
        return store
    }

    /// Empty on a missing or unparseable file, matching `ConfigStore.load` and
    /// `ActivityLog.load` — a corrupt ranking file must never block the launcher.
    static func load(from url: URL) -> [String: FrecencyEntry] {
        guard let data = try? Data(contentsOf: url),
              let store = try? JSONDecoder().decode([String: FrecencyEntry].self, from: data)
        else { return [:] }
        return store
    }

    static func save(_ store: [String: FrecencyEntry], to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(store) else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: url)
    }
}
