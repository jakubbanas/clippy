import AppKit

/// A user-triggerable row in the command launcher. Apps, clipboard clips, and
/// feature actions are all this one type, so the launcher window knows nothing
/// about where a row came from.
struct Command {
    /// Stable across launches — this is the frecency key. Apps use their bundle
    /// path, feature commands use "<featureID>:<slug>", clips use "clip:<copiedAt>".
    let id: String
    let title: String
    /// Dimmed trailing text: an app's path, a clip's source app and age.
    let subtitle: String?
    /// What the fuzzy matcher scores against, when that differs from what is
    /// shown. A clipboard row's `title` is a 60-character preview, so matching
    /// on it would drop any clip whose match sits further in. nil = use `title`.
    let searchText: String?
    let icon: NSImage?
    /// Which group this row is listed under. See `CommandSection`.
    let section: String
    let perform: () -> Void

    init(
        id: String,
        title: String,
        subtitle: String? = nil,
        searchText: String? = nil,
        icon: NSImage? = nil,
        section: String = CommandSection.commands,
        perform: @escaping () -> Void
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.searchText = searchText
        self.icon = icon
        self.section = section
        self.perform = perform
    }
}

extension Command {
    /// An SF Symbol sized for a launcher row. Marked as a template so the window
    /// tints it like secondary text — real app icons are left untinted.
    static func symbol(_ name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 15, weight: .regular))
        image?.isTemplate = true
        return image
    }
}

/// Section names, spelled once.
enum CommandSection {
    static let topApps = "Top Apps"
    static let commands = "Commands"
    static let applications = "Applications"
    static let clipboard = "Clipboard"

    /// Tie-break order when two sections score the same — which is every
    /// section on an empty query, since an empty query scores 0 for everything.
    /// Without this the first view would order sections alphabetically, putting
    /// Clipboard above Commands and Top Apps last.
    private static let order = [topApps, commands, applications, clipboard]

    static func priority(of section: String) -> Int {
        order.firstIndex(of: section) ?? order.count
    }
}
