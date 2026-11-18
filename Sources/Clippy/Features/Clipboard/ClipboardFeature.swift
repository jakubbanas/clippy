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

    private var task: Task<Void, Never>?
    private var clips: [Clip] = []
    private var pins: [Clip] = []
    private var maxItems = 500
    private var enabled = false
    /// Built on first use, not in `start` — the window is AppKit-heavy and most
    /// sessions never open it.
    private var historyWindow: ClipboardHistoryWindow?

    func start(context: FeatureContext) {
        guard task == nil else { return }
        enabled = context.config.clipboard.enabled
        maxItems = context.config.clipboard.maxItems
        guard enabled else { return }

        clips = ClipboardStore.load(from: ClipboardStore.url)
        pins = ClipboardStore.load(from: ClipboardStore.pinnedURL)
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
        historyWindow?.close()
        clips = []
        pins = []
        enabled = false
    }

    func commands() -> [Command] {
        guard enabled else { return [] }
        return [
            Command(
                id: "clipboard:history",
                title: "Clipboard History",
                icon: Command.symbol("clipboard")
            ) { [weak self] in
                self?.openHistory()
            },
        ]
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

    /// Built on first open rather than in `start` — the window is AppKit-heavy
    /// and most sessions never open it.
    private func openHistory() {
        if historyWindow == nil {
            let window = ClipboardHistoryWindow()
            window.onLoad = { [weak self] in
                guard let self else { return ([], []) }
                return (self.pins, ClipboardStore.unpinnedHistory(self.clips, pins: self.pins))
            }
            window.onPick = { clip in
                // Copy only — no synthetic ⌘V, which would need Accessibility.
                // The window restores the previous app so the user's own ⌘V
                // lands there.
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(clip.text, forType: .string)
            }
            window.onDelete = { [weak self] clip in self?.delete(clip) }
            window.onTogglePin = { [weak self] clip in self?.togglePin(clip) }
            historyWindow = window
        }
        historyWindow?.show()
    }

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

    /// Text is the clip's identity: `record` and `pin` each keep one entry per
    /// distinct text. Deleting removes the text from history and pins alike.
    private func delete(_ clip: Clip) {
        clips.removeAll { $0.text == clip.text }
        ClipboardStore.save(clips, to: ClipboardStore.url)
        if pins.contains(where: { $0.text == clip.text }) {
            pins = ClipboardStore.unpin(pins, text: clip.text)
            ClipboardStore.save(pins, to: ClipboardStore.pinnedURL)
        }
    }

    private func togglePin(_ clip: Clip) {
        pins = pins.contains(where: { $0.text == clip.text })
            ? ClipboardStore.unpin(pins, text: clip.text)
            : ClipboardStore.pin(pins, clip: clip)
        ClipboardStore.save(pins, to: ClipboardStore.pinnedURL)
    }

    static func relativeAge(from timestamp: Double, now: Date) -> String {
        let seconds = Int(now.timeIntervalSince1970 - timestamp)
        switch seconds {
        case ..<60: return "just now"
        case ..<3_600: return "\(seconds / 60)m ago"
        case ..<86_400: return "\(seconds / 3_600)h ago"
        default: return "\(seconds / 86_400)d ago"
        }
    }
}
