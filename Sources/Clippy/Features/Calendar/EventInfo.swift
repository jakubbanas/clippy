import EventKit
import Foundation

/// Plain value snapshot of an EKEvent — the only calendar type that crosses
/// out of the EventKit layer.
struct EventInfo {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let location: String?
    let notes: String?
    let url: URL?
    let isAllDay: Bool
    let isDeclined: Bool
    let calendarTitle: String
}

extension EventInfo {
    init(event: EKEvent) {
        self.id = event.eventIdentifier ?? "\(event.title ?? "?")@\(event.startDate.timeIntervalSince1970)"
        self.title = event.title ?? "Untitled event"
        self.start = event.startDate
        self.end = event.endDate
        self.location = event.location
        self.notes = event.notes
        self.url = event.url
        self.isAllDay = event.isAllDay
        self.isDeclined = event.attendees?.contains {
            $0.isCurrentUser && $0.participantStatus == .declined
        } ?? false
        self.calendarTitle = event.calendar?.title ?? ""
    }
}
