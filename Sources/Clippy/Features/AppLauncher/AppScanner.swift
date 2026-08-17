import Foundation

struct AppInfo: Equatable {
    let name: String
    let path: String
}

/// Enumerates installed `.app` bundles. Directories are a parameter so the scan
/// is testable against a temp directory of fake bundles.
enum AppScanner {
    /// Where macOS actually keeps apps. `~/Applications` frequently does not
    /// exist; a missing directory is skipped, not an error.
    static var searchDirectories: [URL] {
        [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/Applications/Utilities"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Applications/Utilities"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
        ]
    }

    /// One level deep only — nested `.app`s inside other bundles are noise.
    /// Deduplicated by display name, first directory winning, so a user's copy
    /// shadows the system one. Sorted for deterministic output.
    static func scan(directories: [URL], fileManager: FileManager = .default) -> [AppInfo] {
        var seen = Set<String>()
        var apps: [AppInfo] = []
        for directory in directories {
            let entries = (try? fileManager.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: nil
            )) ?? []
            for entry in entries where entry.pathExtension == "app" {
                let name = displayName(for: entry)
                guard seen.insert(name).inserted else { continue }
                apps.append(AppInfo(name: name, path: entry.path))
            }
        }
        return apps.sorted { $0.name < $1.name }
    }

    /// `CFBundleDisplayName`, then `CFBundleName`, then the filename. Read from
    /// the plist directly rather than via `Bundle`, which caches aggressively
    /// and would make the tests order-dependent.
    private static func displayName(for bundle: URL) -> String {
        let fallback = bundle.deletingPathExtension().lastPathComponent
        guard let data = try? Data(contentsOf: bundle.appendingPathComponent("Contents/Info.plist")),
              let plist = try? PropertyListSerialization.propertyList(
                  from: data, options: [], format: nil
              ) as? [String: Any]
        else { return fallback }
        if let display = plist["CFBundleDisplayName"] as? String, !display.isEmpty { return display }
        if let name = plist["CFBundleName"] as? String, !name.isEmpty { return name }
        return fallback
    }
}
