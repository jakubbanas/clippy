import Foundation

/// A single Clippy appearance requested by a feature.
struct Announcement {
    /// Dedupe key, e.g. "cal:<eventID>:lead60".
    let id: String
    let featureID: String
    /// Sprite animation name from the agent data, e.g. "Wave", "GetAttention".
    let animation: String
    let title: String
    /// Extra lines rendered under the title in the speech bubble.
    let body: [String]
    let actions: [AnnouncementAction]
    /// Auto-dismiss after this many seconds; nil = stays until acted on.
    let timeout: TimeInterval?
}

struct AnnouncementAction {
    let label: String
    let kind: Kind

    enum Kind {
        case openURL(URL)
        case dismiss
        case snooze(TimeInterval)
        /// Feature-specific behavior. Runs on the main thread, then dismisses
        /// like every other action — features don't control dismissal timing.
        case callback(() -> Void)
    }
}
