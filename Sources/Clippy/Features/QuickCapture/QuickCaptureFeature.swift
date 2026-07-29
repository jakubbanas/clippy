import AppKit
import Foundation

/// Feature #2: capture a reminder from anywhere, then have Clippy pop it back up
/// at the chosen time.
///
/// Exposes a "Quick capture" command (opened via the shared command launcher).
/// The command shows a small panel (text + a short time string). Reminders persist
/// to disk and are checked by a `pollInterval` loop, mirroring the calendar feature.
/// Firing deletes the reminder, so anything overdue while the app was closed or
/// asleep simply fires on the first tick after launch/wake — better late than lost.
final class QuickCaptureFeature: Feature {
    let id = "quickCapture"
    let name = "Quick capture"

    private let store: ReminderStore
    private let pollInterval: TimeInterval = 15

    private var captureWindow: CaptureWindow?
    private var task: Task<Void, Never>?
    private var enabled = false

    init(store: ReminderStore = ReminderStore()) {
        self.store = store
    }

    func start(context: FeatureContext) {
        guard task == nil else { return }
        let config = context.config.quickCapture
        enabled = config.enabled
        guard enabled else { return }
        let snooze = config.snoozeMinutes * 60

        task = Task { [store, announcer = context.announcer, pollInterval] in
            while !Task.isCancelled {
                for reminder in Self.dueReminders(reminders: store.all(), now: Date()) {
                    store.remove(id: reminder.id)
                    announcer.announce(Self.announcement(for: reminder, snooze: snooze))
                }
                try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        enabled = false
        DispatchQueue.main.async { [weak self] in
            self?.captureWindow?.close()
            self?.captureWindow = nil
        }
    }

    func commands() -> [Command] {
        guard enabled else { return [] }
        return [Command(title: "Quick capture") { [weak self] in self?.showCapturePanel() }]
    }

    private func showCapturePanel() {
        if captureWindow == nil {
            let window = CaptureWindow()
            window.onSubmit = { [store] text, timeString in
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty,
                      let fireAt = ReminderTime.parse(timeString, now: Date()) else { return false }
                store.add(Reminder(text: trimmed, fireAt: fireAt))
                return true
            }
            captureWindow = window
        }
        captureWindow?.show()
    }

    /// Pure fire computation: reminders whose time has arrived. No grace-window
    /// lower bound — a missed personal reminder should always surface.
    static func dueReminders(reminders: [Reminder], now: Date) -> [Reminder] {
        reminders.filter { $0.fireAt <= now }
    }

    private static func announcement(for reminder: Reminder, snooze: TimeInterval) -> Announcement {
        Announcement(
            id: "quickCapture:\(reminder.id.uuidString)",
            featureID: "quickCapture",
            animation: "GetAttention",
            title: "It looks like you wanted a reminder!",
            body: [reminder.text],
            actions: [
                AnnouncementAction(label: "Snooze \(Int((snooze / 60).rounded())) min", kind: .snooze(snooze)),
                AnnouncementAction(label: "Dismiss", kind: .dismiss),
            ],
            timeout: nil
        )
    }
}
