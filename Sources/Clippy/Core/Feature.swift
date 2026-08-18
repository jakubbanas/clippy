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
    /// Query-dependent rows for the launcher — apps matching what was typed,
    /// clips matching what was typed. Called on every keystroke, so it must be
    /// fast and synchronous: match against an in-memory cache, never disk.
    /// An empty query means "the window just opened"; return your few most
    /// useful rows, or none.
    func searchItems(query: String) -> [Command]
    /// Rebuilds one previously-picked row from its id, so the launcher can turn
    /// remembered ids (frecency) back into rows without knowing how to construct
    /// them. nil = not this feature's id, or the target no longer exists.
    func item(withID id: String) -> Command?
}

extension Feature {
    func commands() -> [Command] { [] }
    func searchItems(query: String) -> [Command] { [] }
    func item(withID id: String) -> Command? { nil }
}

struct FeatureContext {
    let announcer: Announcer
    let config: AppConfig
}

/// Thread-safe handle features use to request a Clippy appearance or set a
/// persistent status. Hops to the main thread before touching the presenter.
final class Announcer {
    private let deliver: (Announcement) -> Void
    private let deliverStatus: (String?, Double?) -> Void

    init(deliver: @escaping (Announcement) -> Void, deliverStatus: @escaping (String?, Double?) -> Void) {
        self.deliver = deliver
        self.deliverStatus = deliverStatus
    }

    func announce(_ announcement: Announcement) {
        DispatchQueue.main.async { [deliver] in
            deliver(announcement)
        }
    }

    /// Sets or clears a persistent status shown alongside Clippy, independent of
    /// the announcement queue. Pass nil text to clear. `progress` (0...1) shows a
    /// fill bar alongside the text; nil hides the bar and shows text only.
    func setStatus(_ text: String?, progress: Double? = nil) {
        DispatchQueue.main.async { [deliverStatus] in
            deliverStatus(text, progress)
        }
    }
}
