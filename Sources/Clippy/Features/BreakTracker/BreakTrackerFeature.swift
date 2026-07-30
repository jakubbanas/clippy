import Foundation

/// Feature #5: notice when you come back from a break and tell you how long it was.
///
/// Polls idle time; when it drops (you touched the machine again) after having been
/// idle past `minBreakMinutes`, Clippy pops "Welcome back — away for N min." Gives
/// you a passive sense of how much time breaks actually eat. Break length is
/// measured to ±`pollInterval`, since the return is only seen on the next poll.
final class BreakTrackerFeature: Feature {
    let id = "breakTracker"
    let name = "Break tracker"

    private let pollInterval: TimeInterval = 15
    private var task: Task<Void, Never>?

    func start(context: FeatureContext) {
        guard task == nil else { return }
        let config = context.config.breakTracker
        guard config.enabled else { return }
        let threshold = config.minBreakMinutes * 60

        task = Task { [announcer = context.announcer, pollInterval, threshold] in
            var previousIdle: TimeInterval = 0
            while !Task.isCancelled {
                let idle = UserActivity.idleSeconds()
                if let awaySeconds = Self.breakEnded(previousIdle: previousIdle, currentIdle: idle, threshold: threshold) {
                    announcer.announce(Self.announcement(awaySeconds: awaySeconds))
                }
                previousIdle = idle
                try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    /// Pure return-detection: a break just ended when idle dropped (input resumed)
    /// and the idle before the drop was at least `threshold`. Returns that idle
    /// duration (the break length), else nil.
    static func breakEnded(previousIdle: TimeInterval, currentIdle: TimeInterval, threshold: TimeInterval) -> TimeInterval? {
        guard currentIdle < previousIdle, previousIdle >= threshold else { return nil }
        return previousIdle
    }

    static func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes) min"
    }

    private static func announcement(awaySeconds: TimeInterval) -> Announcement {
        Announcement(
            id: "breakTracker:\(Int(Date().timeIntervalSince1970))",
            featureID: "breakTracker",
            animation: "Greeting",
            title: "Welcome back!",
            body: ["You were away for \(formatDuration(awaySeconds))."],
            actions: [AnnouncementAction(label: "Thanks", kind: .dismiss)],
            timeout: 15
        )
    }
}
