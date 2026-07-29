import AppKit

/// Owns the Clippy window and serializes announcements one at a time.
/// Main thread only — features reach it through `Announcer`.
final class Presenter {
    private let window: ClippyWindow
    private var queue: [Announcement] = []
    private var current: Announcement?
    private var timeoutWork: DispatchWorkItem?

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
            NSWorkspace.shared.open(url)
        case .dismiss:
            break
        case .snooze(let interval):
            if let announcement = current {
                DispatchQueue.main.asyncAfter(deadline: .now() + interval) { [weak self] in
                    self?.enqueue(announcement)
                }
            }
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
