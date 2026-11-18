import AppKit

/// Owns the Clippy window and serializes announcements one at a time.
/// Main thread only — features reach it through `Announcer`.
final class Presenter {
    private let window: ClippyWindow
    private var queue: [Announcement] = []
    private var current: Announcement?
    private var timeoutWork: DispatchWorkItem?
    /// Bundle ID for opening web links; nil = system default. Set from config.
    var browser: String?

    init(window: ClippyWindow) {
        self.window = window
        window.onAction = { [weak self] kind in
            self?.handle(kind)
        }
    }

    func enqueue(_ announcement: Announcement) {
        queue.append(announcement)
        presentNextIfIdle()
    }

    /// Passes straight through to the window, bypassing the announcement queue —
    /// a status update must not wait for a queued announcement to drain.
    func setStatus(_ text: String?, progress: Double? = nil) {
        window.setStatus(text, progress: progress)
    }

    /// Shows/hides the window directly, independent of the announcement queue —
    /// used by the tray menu's "Hide Clippy" / "Show Clippy" toggle.
    func setVisible(_ visible: Bool) {
        if visible {
            window.showManually()
        } else {
            window.hideManually()
        }
    }

    private func presentNextIfIdle() {
        guard current == nil, !queue.isEmpty else { return }
        let announcement = queue.removeFirst()
        current = announcement
        window.show(announcement)

        if let timeout = announcement.timeout {
            let work = DispatchWorkItem { [weak self] in
                self?.dismissCurrent()
            }
            timeoutWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: work)
        }
    }

    private func handle(_ kind: AnnouncementAction.Kind) {
        switch kind {
        case .openURL(let url):
            // Web links (meeting "Join") go to the chosen browser; other schemes (e.g. System Settings),
            // no choice, or an uninstalled browser use the system default handler.
            if url.scheme?.hasPrefix("http") == true,
               let browser,
               let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: browser) {
                NSWorkspace.shared.open([url], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
            } else {
                NSWorkspace.shared.open(url)
            }
        case .dismiss:
            break
        case .snooze(let interval):
            if let announcement = current {
                DispatchQueue.main.asyncAfter(deadline: .now() + interval) { [weak self] in
                    self?.enqueue(announcement)
                }
            }
        case .callback(let action):
            action()
        }
        dismissCurrent()
    }

    private func dismissCurrent() {
        guard current != nil else { return }
        timeoutWork?.cancel()
        timeoutWork = nil
        window.dismiss { [weak self] in
            self?.current = nil
            self?.presentNextIfIdle()
        }
    }
}
