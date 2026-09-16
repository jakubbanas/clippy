import AppKit

/// Owns the single global hotkey and the search window it opens.
///
/// Static rows come from each feature's `commands()`, collected once per
/// configure; query-dependent rows come from `searchItems(query:)` on every
/// keystroke. Ranking lives in `LauncherRanking`; this class only fans out,
/// records frecency, and runs what was picked.
final class CommandLauncher {
    private var hotKey: HotKey?
    private var features: [Feature] = []
    private var staticCommands: [Command] = []
    private var frecency: [String: FrecencyEntry] = [:]
    private let window = LauncherWindow()

    init() {
        window.onQueryChanged = { [weak self] query in self?.rank(query) ?? [] }
        window.onPick = { [weak self] command in self?.run(command) }
    }

    /// (Re)binds the hotkey and refreshes the command sources. Safe to call on
    /// reload — `AppDelegate.reloadFeatures` calls `stop()` first.
    func configure(hotkey: String, features: [Feature]) {
        self.features = features
        self.staticCommands = features.flatMap { $0.commands() }
        self.frecency = Frecency.load(from: Frecency.url)

        hotKey?.unregister()
        hotKey = nil
        guard let combo = HotKeyCombo.parse(hotkey) else {
            NSLog("Launcher: could not parse hotkey \"\(hotkey)\"")
            return
        }
        hotKey = HotKey(keyCode: combo.keyCode, modifiers: combo.modifiers) { [weak self] in
            self?.window.show()
        }
    }

    func stop() {
        hotKey?.unregister()
        hotKey = nil
        window.close()
        features = []
        staticCommands = []
    }

    /// How many top apps the empty-query first view shows.
    private static let topAppCount = 5

    private func rank(_ query: String) -> [LauncherSection] {
        let dynamic = features.flatMap { $0.searchItems(query: query) }
        let topApps = query.isEmpty ? topAppRows() : []
        return LauncherRanking.sections(
            for: query,
            commands: staticCommands + dynamic + topApps,
            frecency: frecency,
            now: Date()
        )
    }

    /// The most-used apps, for the first view before anything is typed. Ordered
    /// by use count (not recency — that is what `Frecency.boost` does while
    /// typing). Only apps appear: no other feature implements `item(withID:)`,
    /// so remembered ids like "focus:start" resolve to nil and drop out. More
    /// ids than needed are requested for that reason, then capped.
    private func topAppRows() -> [Command] {
        let ids = Frecency.topUsed(frecency, limit: Self.topAppCount * 4)
        let rows = ids.compactMap { id -> Command? in
            for feature in features {
                if let row = feature.item(withID: id) { return row }
            }
            return nil
        }
        return rows.prefix(Self.topAppCount).map { row in
            // Re-tagged so these sit in their own section rather than mixing
            // with typed app results.
            Command(
                id: row.id,
                title: row.title,
                subtitle: row.subtitle,
                searchText: row.searchText,
                icon: row.icon,
                section: CommandSection.topApps,
                perform: row.perform
            )
        }
    }

    private func run(_ command: Command) {
        frecency = Frecency.record(frecency, id: command.id, now: Date())
        Frecency.save(frecency, to: Frecency.url)
        command.perform()
    }
}
