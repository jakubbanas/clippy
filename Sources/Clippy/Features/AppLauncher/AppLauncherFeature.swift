import AppKit

/// Fuzzy app launching. Scans installed bundles once on `start`, then answers
/// launcher queries from that in-memory cache — `searchItems` runs on every
/// keystroke, so it must never touch disk.
///
/// Installing an app mid-session needs "Reload Config" (which calls `stop()`
/// then `start(context:)`). A filesystem watcher is not worth it here.
final class AppLauncherFeature: Feature {
    let id = "appLauncher"
    let name = "App Launcher"

    private var apps: [(info: AppInfo, icon: NSImage)] = []
    private var scanTask: Task<Void, Never>?
    private var enabled = false

    func start(context: FeatureContext) {
        guard scanTask == nil else { return }
        enabled = context.config.appLauncher.enabled
        guard enabled else { return }

        scanTask = Task { [weak self] in
            let found = AppScanner.scan(directories: AppScanner.searchDirectories)
            guard !Task.isCancelled else { return }
            // Icons come from NSWorkspace, so build the cache on the main thread.
            // `self` is re-captured here rather than reused from the outer Task:
            // crossing the concurrency boundary with a captured var is an error
            // under the Swift 6 language mode.
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.apps = found.map { ($0, NSWorkspace.shared.icon(forFile: $0.path)) }
            }
        }
    }

    func stop() {
        scanTask?.cancel()
        scanTask = nil
        apps = []
        enabled = false
    }

    func searchItems(query: String) -> [Command] {
        // An unfiltered list of every installed app is noise; the app you want
        // is always two keystrokes away.
        guard enabled, !query.isEmpty else { return [] }
        return apps.compactMap { entry in
            guard FuzzyMatch.score(query, in: entry.info.name) != nil else { return nil }
            return Command(
                id: "app:\(entry.info.path)",
                title: entry.info.name,
                subtitle: entry.info.path,
                icon: entry.icon,
                section: CommandSection.applications
            ) {
                let url = URL(fileURLWithPath: entry.info.path)
                NSWorkspace.shared.openApplication(
                    at: url, configuration: NSWorkspace.OpenConfiguration()
                ) { _, error in
                    if let error { NSLog("AppLauncher: could not open \(url.path): \(error)") }
                }
            }
        }
    }
}
