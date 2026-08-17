import AppKit

/// Searchable clipboard history.
///
/// `NSPasteboard` has no change notification, so this polls `changeCount` — the
/// cheapest available signal. Everything worth testing is factored into the two
/// static helpers below; the rest is polling and AppKit glue.
final class ClipboardFeature: Feature {
    let id = "clipboard"
    let name = "Clipboard History"

    private static let pollSeconds: UInt64 = 1
    private static let maxBytes = 100_000
    private static let emptyQueryRows = 3
    /// How much of a clip `LauncherRanking` gets to match against, via the row's
    /// `searchText`: a 2000-character clip would otherwise be crushed by the
    /// skipped-character penalty, and the row only shows the first line anyway.
    private static let scoringPrefix = 200

    private var task: Task<Void, Never>?
    private var clips: [Clip] = []
    private var maxItems = 500
    private var enabled = false

    func start(context: FeatureContext) {
        guard task == nil else { return }
        enabled = context.config.clipboard.enabled
        maxItems = context.config.clipboard.maxItems
        guard enabled else { return }

        clips = ClipboardStore.load(from: ClipboardStore.url)
        task = Task { [weak self] in
            var lastChangeCount = await MainActor.run { NSPasteboard.general.changeCount }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Self.pollSeconds * 1_000_000_000)
                guard !Task.isCancelled else { return }
                let current = await MainActor.run { NSPasteboard.general.changeCount }
                guard current != lastChangeCount else { continue }
                lastChangeCount = current
                await MainActor.run { [weak self] in self?.capture() }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        clips = []
        enabled = false
    }

    func commands() -> [Command] {
        guard enabled else { return [] }
        return [
            Command(id: "clipboard:clear", title: "Clear clipboard history") { [weak self] in
                self?.clips = []
                try? FileManager.default.removeItem(at: ClipboardStore.url)
            },
        ]
    }

    func searchItems(query: String) -> [Command] {
        guard enabled else { return [] }
        // No scoring or sorting here — every row is scored exactly once, in
        // LauncherRanking, against the `searchText` set by `row(for:)`. Doing it
        // twice is how a clip gets filtered in by one window and out by another.
        let matches = query.isEmpty ? Array(clips.prefix(Self.emptyQueryRows)) : clips
        return matches.map(row(for:))
    }

    // MARK: - Pure helpers

    /// Password managers (1Password, Keychain Access) mark their pasteboard
    /// writes concealed; clipboard managers mark throwaway writes transient.
    /// Honor both, and never store blank or enormous clips.
    static func shouldSkip(text: String, types: [String], maxBytes: Int) -> Bool {
        if types.contains("org.nspasteboard.ConcealedType") { return true }
        if types.contains("de.petermaurer.TransientPasteboardType") { return true }
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        if text.utf8.count > maxBytes { return true }
        return false
    }

    /// First line, whitespace collapsed, truncated — a launcher row is one line.
    static func rowTitle(for text: String, maxLength: Int = 60) -> String {
        let collapsed = text
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .joined(separator: " ")
        return collapsed.count > maxLength ? String(collapsed.prefix(maxLength)) + "…" : collapsed
    }

    // MARK: - Private

    private func capture() {
        let pasteboard = NSPasteboard.general
        guard let text = pasteboard.string(forType: .string) else { return }
        let types = (pasteboard.types ?? []).map(\.rawValue)
        guard !Self.shouldSkip(text: text, types: types, maxBytes: Self.maxBytes) else { return }

        let clip = Clip(
            copiedAt: Date().timeIntervalSince1970,
            app: NSWorkspace.shared.frontmostApplication?.localizedName,
            text: text
        )
        clips = ClipboardStore.record(clips, clip: clip, maxItems: maxItems)
        ClipboardStore.save(clips, to: ClipboardStore.url)
    }

    private func row(for clip: Clip) -> Command {
        let age = Self.relativeAge(from: clip.copiedAt, now: Date())
        let subtitle = [clip.app, age].compactMap { $0 }.joined(separator: " · ")
        return Command(
            id: "clip:\(clip.copiedAt)",
            title: Self.rowTitle(for: clip.text),
            subtitle: subtitle,
            // Matched against this, displayed as `title`. Capped so a 2000-char
            // clip is not crushed by the skipped-character penalty.
            searchText: String(clip.text.prefix(Self.scoringPrefix)),
            section: CommandSection.clipboard
        ) {
            // Copy only — no synthetic ⌘V, which would need Accessibility.
            // LauncherWindow restores the previous app so the user's ⌘V lands there.
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(clip.text, forType: .string)
        }
    }

    private static func relativeAge(from timestamp: Double, now: Date) -> String {
        let seconds = Int(now.timeIntervalSince1970 - timestamp)
        switch seconds {
        case ..<60: return "just now"
        case ..<3_600: return "\(seconds / 60)m ago"
        case ..<86_400: return "\(seconds / 3_600)h ago"
        default: return "\(seconds / 86_400)d ago"
        }
    }
}
