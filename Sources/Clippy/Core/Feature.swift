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
    /// User-triggerable actions this feature contributes to the command launcher.
    /// Call after `start(context:)`. Defaults to none.
    func commands() -> [Command]
}

extension Feature {
    func commands() -> [Command] { [] }
}

struct FeatureContext {
    let announcer: Announcer
    let config: AppConfig
}

/// Thread-safe handle features use to request a Clippy appearance or set a
/// persistent status. Hops to the main thread before touching the presenter.
final class Announcer {
    private let deliver: (Announcement) -> Void
    private let deliverStatus: (String?) -> Void

    init(deliver: @escaping (Announcement) -> Void, deliverStatus: @escaping (String?) -> Void) {
        self.deliver = deliver
        self.deliverStatus = deliverStatus
    }

    func announce(_ announcement: Announcement) {
        DispatchQueue.main.async { [deliver] in
            deliver(announcement)
        }
    }

    /// Sets or clears a persistent status shown alongside Clippy, independent of
    /// the announcement queue. Pass nil to clear.
    func setStatus(_ text: String?) {
        DispatchQueue.main.async { [deliverStatus] in
            deliverStatus(text)
        }
    }
}
