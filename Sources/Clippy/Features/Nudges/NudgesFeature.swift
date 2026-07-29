import Foundation

/// Feature #3: recurring nudges (drink water, take a break).
///
/// Each configured nudge fires every `everyMinutes` while enabled. Timing is
/// in-memory only — unlike quick-capture one-shots, a nudge missed while the app
/// was closed doesn't matter, so there's nothing to persist. `lastFired` starts
/// at launch time, so the first nudge lands one interval later (no startup nag).
final class NudgesFeature: Feature {
    let id = "nudges"
    let name = "Recurring nudges"

    private let pollInterval: TimeInterval = 15
    private var task: Task<Void, Never>?

    func start(context: FeatureContext) {
        guard task == nil else { return }
        let nudges = context.config.nudges.filter(\.enabled)
        guard !nudges.isEmpty else { return }

        task = Task { [announcer = context.announcer, pollInterval] in
            var lastFired = Dictionary(uniqueKeysWithValues: nudges.map { ($0.name, Date()) })
            while !Task.isCancelled {
                let now = Date()
                for nudge in Self.dueNudges(nudges: nudges, now: now, lastFired: lastFired) {
                    lastFired[nudge.name] = now
                    announcer.announce(Self.announcement(for: nudge))
                }
                try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    /// Pure fire computation: enabled nudges whose interval has elapsed since they
    /// last fired.
    static func dueNudges(nudges: [NudgeConfig], now: Date, lastFired: [String: Date]) -> [NudgeConfig] {
        nudges.filter { nudge in
            guard nudge.enabled, let last = lastFired[nudge.name] else { return false }
            return now.timeIntervalSince(last) >= nudge.everyMinutes * 60
        }
    }

    private static func announcement(for nudge: NudgeConfig) -> Announcement {
        Announcement(
            id: "nudge:\(nudge.name):\(Int(Date().timeIntervalSince1970))",
            featureID: "nudges",
            animation: "GetAttention",
            title: nudge.message,
            body: [],
            actions: [
                AnnouncementAction(label: "Snooze 10 min", kind: .snooze(600)),
                AnnouncementAction(label: "Dismiss", kind: .dismiss),
            ],
            timeout: 30
        )
    }
}
