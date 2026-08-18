import AppKit
import Foundation

/// Feature #4: body-doubling focus sessions.
///
/// Exposes a "Start focus" command (opened via the shared command launcher). It
/// shows a panel to declare a goal + duration. Clippy pops once to start the block,
/// stays silent through it apart from an optional halfway check-in, then pops at
/// the end with a check-out prompt tied to the declared goal.
final class FocusSessionFeature: Feature {
    let id = "focus"
    let name = "Focus sessions"

    private var announcer: Announcer?
    private var startWindow: FocusStartWindow?
    private var sessionTask: Task<Void, Never>?
    private var statusTickTask: Task<Void, Never>?
    private static let statusTickInterval: TimeInterval = 15

    private var defaultMinutes: Double = 25
    private var midCheckIn = false
    private var enabled = false

    func start(context: FeatureContext) {
        guard announcer == nil else { return }
        let config = context.config.focus
        enabled = config.enabled
        guard enabled else { return }
        announcer = context.announcer
        defaultMinutes = config.defaultMinutes
        midCheckIn = config.midCheckIn
    }

    func stop() {
        enabled = false
        sessionTask?.cancel()
        sessionTask = nil
        statusTickTask?.cancel()
        statusTickTask = nil
        announcer?.setStatus(nil)
        announcer = nil
        DispatchQueue.main.async { [weak self] in
            self?.startWindow?.close()
            self?.startWindow = nil
        }
    }

    func commands() -> [Command] {
        guard enabled else { return [] }
        return [
            Command(
                id: "focus:start",
                title: "Start focus",
                icon: Command.symbol("timer")
            ) { [weak self] in self?.showStartPanel() },
        ]
    }

    private func showStartPanel() {
        if startWindow == nil {
            let window = FocusStartWindow(defaultMinutes: defaultMinutes)
            window.onStart = { [weak self] goal, minutes in
                self?.beginSession(goal: goal, minutes: minutes)
            }
            startWindow = window
        }
        startWindow?.show()
    }

    /// Runs one session end-to-end. Called on the main thread (command action and
    /// the "Another round" check-out action). Cancels any session already running.
    private func beginSession(goal: String, minutes: Double) {
        guard let announcer else { return }
        sessionTask?.cancel()
        statusTickTask?.cancel()
        announcer.announce(Self.startAnnouncement(goal: goal, minutes: minutes))

        let total = minutes * 60
        let endDate = Date().addingTimeInterval(total)
        statusTickTask = Task {
            while !Task.isCancelled {
                let remaining = endDate.timeIntervalSinceNow
                guard remaining > 0 else {
                    announcer.setStatus(nil)
                    return
                }
                announcer.setStatus(
                    Self.statusText(goal: goal, remaining: remaining),
                    progress: Self.progressFraction(remaining: remaining, total: total)
                )
                let sleepDuration = min(Self.statusTickInterval, remaining)
                try? await Task.sleep(nanoseconds: UInt64(sleepDuration * 1_000_000_000))
            }
        }

        let beats = Self.beats(durationMinutes: minutes, midCheckIn: midCheckIn)
        sessionTask = Task { [weak self] in
            var elapsed: TimeInterval = 0
            for beat in beats {
                try? await Task.sleep(nanoseconds: UInt64(max(0, beat.offset - elapsed) * 1_000_000_000))
                if Task.isCancelled { return }
                elapsed = beat.offset
                switch beat.kind {
                case .mid:
                    announcer.announce(Self.midAnnouncement(goal: goal))
                case .end:
                    announcer.announce(Self.endAnnouncement(goal: goal) {
                        self?.beginSession(goal: goal, minutes: minutes)
                    })
                }
            }
        }
    }

    enum Beat: Equatable { case mid, end }

    /// Pure beat schedule: offsets (seconds from start) at which Clippy should pop.
    /// The mid check-in is included only when enabled and the block is long enough
    /// to be worth interrupting.
    static func beats(durationMinutes: Double, midCheckIn: Bool) -> [(offset: TimeInterval, kind: Beat)] {
        let total = durationMinutes * 60
        var beats: [(offset: TimeInterval, kind: Beat)] = []
        if midCheckIn && durationMinutes >= 20 {
            beats.append((total / 2, .mid))
        }
        beats.append((total, .end))
        return beats
    }

    /// Pure formatting for the persistent status label. `remaining` is clamped to
    /// zero before formatting — callers are expected to clear the status once it
    /// reaches zero rather than display "0m left".
    static func statusText(goal: String, remaining: TimeInterval) -> String {
        let clamped = max(0, remaining)
        if clamped < 60 {
            return "\(goal) — under a minute"
        }
        let minutes = Int((clamped / 60).rounded(.up))
        return "\(goal) — \(minutes)m left"
    }

    /// Elapsed fraction of the session, clamped to 0...1. `total <= 0` (a
    /// degenerate 0-minute session) returns 1 rather than dividing by zero.
    static func progressFraction(remaining: TimeInterval, total: TimeInterval) -> Double {
        guard total > 0 else { return 1 }
        let elapsed = total - remaining
        return max(0, min(1, elapsed / total))
    }

    private static func startAnnouncement(goal: String, minutes: Double) -> Announcement {
        Announcement(
            id: "focus:start:\(Int(Date().timeIntervalSince1970))",
            featureID: "focus",
            animation: "GetAttention",
            title: "Locked in for \(Int(minutes)) minutes!",
            body: [goal, "I'll check back when time's up. Go get it."],
            actions: [AnnouncementAction(label: "Let's go", kind: .dismiss)],
            timeout: 10
        )
    }

    private static func midAnnouncement(goal: String) -> Announcement {
        Announcement(
            id: "focus:mid:\(Int(Date().timeIntervalSince1970))",
            featureID: "focus",
            animation: "GetAttention",
            title: "Halfway there — still on it?",
            body: [goal],
            actions: [AnnouncementAction(label: "Yep", kind: .dismiss)],
            timeout: 15
        )
    }

    private static func endAnnouncement(goal: String, onAnother: @escaping () -> Void) -> Announcement {
        Announcement(
            id: "focus:end:\(Int(Date().timeIntervalSince1970))",
            featureID: "focus",
            animation: "Congratulate",
            title: "Time! Did you finish?",
            body: [goal],
            actions: [
                AnnouncementAction(label: "Done ✅", kind: .dismiss),
                AnnouncementAction(label: "Another round", kind: .callback(onAnother)),
            ],
            timeout: nil
        )
    }
}
