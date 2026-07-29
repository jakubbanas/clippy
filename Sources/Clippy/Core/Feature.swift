import Foundation

/// A pluggable app capability. Each feature runs its own background work and
/// pushes `Announcement`s through the context's announcer. Adding a feature =
/// one new module implementing this protocol + one line in Registry.swift.
protocol Feature {
    var id: String { get }
    var name: String { get }
    /// Called once at startup. The feature owns its own loop/tasks.
    func start(context: FeatureContext)
}

struct FeatureContext {
    let announcer: Announcer
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
