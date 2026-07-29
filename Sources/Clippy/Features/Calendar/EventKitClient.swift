import EventKit
import Foundation

/// Wraps EKEventStore: permission flow + event queries returning plain EventInfo.
final class EventKitClient {
    enum AccessError: Error {
        case denied
        case restricted
    }

    private let store = EKEventStore()

    /// Ensures full calendar access, prompting the user if undetermined.
    func requestAccess() async throws {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            return
        case .notDetermined:
            let granted = try await store.requestFullAccessToEvents()
            if !granted { throw AccessError.denied }
        case .restricted:
            throw AccessError.restricted
        default:
            throw AccessError.denied
        }
    }

    /// Events in [from, to), optionally limited to calendars by title.
    func events(from: Date, to: Date, calendarTitles: [String]? = nil) -> [EventInfo] {
        var calendars = store.calendars(for: .event)
        if let titles = calendarTitles {
            calendars = calendars.filter { titles.contains($0.title) }
        }
        let predicate = store.predicateForEvents(withStart: from, end: to, calendars: calendars)
        return store.events(matching: predicate).map(EventInfo.init)
    }
}
