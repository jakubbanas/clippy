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

    private func rank(_ query: String) -> [LauncherSection] {
        let dynamic = features.flatMap { $0.searchItems(query: query) }
        return LauncherRanking.sections(
            for: query,
            commands: staticCommands + dynamic,
            frecency: frecency,
            now: Date()
        )
    }

    private func run(_ command: Command) {
        // Clips are skipped: their ids are timestamps that never recur, so an
        // entry could never be hit twice — it would only grow the file forever.
        // Clips are already recency-ordered by the feature.
        if command.section != CommandSection.clipboard {
            frecency = Frecency.record(frecency, id: command.id, now: Date())
            Frecency.save(frecency, to: Frecency.url)
        }
        command.perform()
    }
}
