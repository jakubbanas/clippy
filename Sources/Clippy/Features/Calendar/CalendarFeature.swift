import AppKit
import Foundation

/// Feature #1: Clippy announces upcoming calendar meetings.
///
/// Polls EventKit every `pollInterval` and fires an announcement for each
/// event/lead-time pair once. Polling (vs change notifications) keeps the loop
/// self-healing across event edits and sleep/wake at negligible local-query cost.
final class CalendarFeature: Feature {
    let id = "calendar"
    let name = "Calendar reminders"

    private let client = EventKitClient()
    /// Seconds before event start to announce.
    private var leadTimes: [TimeInterval] = [60, 0]
    private var calendarTitles: [String]?
    private let pollInterval: TimeInterval = 15
    /// Fire at most this long after the intended moment (covers wake-from-sleep).
    private let graceWindow: TimeInterval = 90

    /// Reminder key → event start (kept so pruning is possible).
    private var fired: [String: Date] = [:]

    func start(context: FeatureContext) {
        guard context.config.calendar.enabled else { return }
        leadTimes = context.config.calendar.leadMinutes.map { $0 * 60 }
        calendarTitles = context.config.calendar.calendars
        Task { await run(context) }
    }

    private func run(_ context: FeatureContext) async {
        do {
            try await client.requestAccess()
        } catch {
            context.announcer.announce(Self.accessDeniedAnnouncement())
            return
        }

        while !Task.isCancelled {
            tick(now: Date(), announcer: context.announcer)
            try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }
    }

    private func tick(now: Date, announcer: Announcer) {
        let events = client.events(
            from: now.addingTimeInterval(-3600),
            to: now.addingTimeInterval(24 * 3600),
            calendarTitles: calendarTitles
        )

        for due in Self.dueReminders(events: events, now: now, leadTimes: leadTimes, graceWindow: graceWindow, alreadyFired: Set(fired.keys)) {
            fired[due.key] = due.event.start
            announcer.announce(Self.announcement(for: due.event, lead: due.lead, key: due.key))
        }

        fired = fired.filter { $0.value > now.addingTimeInterval(-3600) }
    }

    struct DueReminder {
        let key: String
        let event: EventInfo
        let lead: TimeInterval
    }

    /// Pure reminder computation: which event/lead pairs should fire at `now`.
    static func dueReminders(
        events: [EventInfo],
        now: Date,
        leadTimes: [TimeInterval],
        graceWindow: TimeInterval,
        alreadyFired: Set<String>
    ) -> [DueReminder] {
        var due: [DueReminder] = []
        for event in events where !event.isAllDay && !event.isDeclined {
            for lead in leadTimes {
                let fireTime = event.start.addingTimeInterval(-lead)
                let key = "\(event.id):\(Int(lead)):\(Int(event.start.timeIntervalSince1970))"
                guard fireTime <= now,
                      now.timeIntervalSince(fireTime) < graceWindow,
                      // a "meeting in N minutes" reminder is pointless once it started
                      !(lead > 0 && event.start <= now),
                      !alreadyFired.contains(key)
                else { continue }
                due.append(DueReminder(key: key, event: event, lead: lead))
            }
        }
        return due
    }

    private static func announcement(for event: EventInfo, lead: TimeInterval, key: String) -> Announcement {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let timeRange = "\(formatter.string(from: event.start)) – \(formatter.string(from: event.end))"

        var actions: [AnnouncementAction] = []
        if let link = MeetingLinks.extract(from: event) {
            actions.append(AnnouncementAction(label: "Join", kind: .openURL(link)))
        }
        actions.append(AnnouncementAction(label: "Snooze 5 min", kind: .snooze(300)))
        actions.append(AnnouncementAction(label: "Dismiss", kind: .dismiss))

        let startAnimations = ["Wave", "Greeting", "GetAttention", "Congratulate", "GetArtsy"]
        return Announcement(
            id: key,
            featureID: "calendar",
            animation: lead > 0 ? "GetAttention" : startAnimations.randomElement()!,
            title: lead > 0
                ? "It looks like you have a meeting in \(Int(lead / 60)) minute\(lead >= 120 ? "s" : "")!"
                : "Your meeting is starting now!",
            body: [timeRange, event.title],
            actions: actions,
            timeout: 60
        )
    }

    private static func accessDeniedAnnouncement() -> Announcement {
        Announcement(
            id: "calendar:access-denied",
            featureID: "calendar",
            animation: "Alert",
            title: "I can't see your calendar!",
            body: ["Grant access in System Settings, then relaunch me."],
            actions: [
                AnnouncementAction(
                    label: "Open Settings",
                    kind: .openURL(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
                ),
                AnnouncementAction(label: "Dismiss", kind: .dismiss),
            ],
            timeout: nil
        )
    }
}
