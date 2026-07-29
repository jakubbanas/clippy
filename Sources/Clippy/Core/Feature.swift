import Foundation

/// A pluggable app capability. Each feature runs its own background work and
/// pushes `Announcement`s through the context's announcer. Adding a feature =
/// one new module implementing this protocol + one line in Registry.swift.
protocol Feature {
    var id: String { get }
    var name: String { get }
    /// Spawns the feature's background work. Safe to call again after `stop()`.
    func start(context: FeatureContext)
    /// Cancels background work started by `start`. No-op if not running.
    func stop()
}

struct FeatureContext {
    let announcer: Announcer
    let config: AppConfig
}

/// Thread-safe handle features use to request a Clippy appearance.
/// Hops to the main thread before touching the presenter.
final class Announcer {
    private let deliver: (Announcement) -> Void

    init(deliver: @escaping (Announcement) -> Void) {
        self.deliver = deliver
    }

    func announce(_ announcement: Announcement) {
        DispatchQueue.main.async { [deliver] in
            deliver(announcement)
        }
    }
}
