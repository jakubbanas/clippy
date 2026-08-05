import Foundation

/// Feature #6: silently logs active-vs-idle time and calendar-meeting
/// overlap, one row per hour, to a monthly CSV — no popups, just a record
/// for the user to open and see which hours they're actually productive.
///
/// Polls every 15s (same cadence as `BreakTrackerFeature`), reusing
/// `UserActivity.idleSeconds()` for the activity signal and a second
/// `EventKitClient` for the meeting-overlap check. Every poll re-reads,
/// merges, and rewrites the current month's CSV (`ActivityLog`), so
/// reload/restart/crash never duplicates or loses a row for the same hour.
final class ActivityLogFeature: Feature {
    let id = "activityLog"
    let name = "Activity log"

    private let pollInterval: TimeInterval = 15
    private var task: Task<Void, Never>?
    private let eventKitClient = EventKitClient()

    func start(context: FeatureContext) {
        guard task == nil else { return }
        let config = context.config.activityLog
        guard config.enabled else { return }
        let threshold = config.idleThresholdSeconds

        task = Task { [pollInterval, threshold, eventKitClient] in
            try? await eventKitClient.requestAccess()

            while !Task.isCancelled {
                let now = Date()
                let calendar = Calendar.current
                let key = Self.bucketKey(for: now, calendar: calendar)
                let hourStart = calendar.date(bySettingHour: key.hour, minute: 0, second: 0, of: now) ?? now
                let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart) ?? now

                let isActive = UserActivity.idleSeconds() < threshold
                // Fails open: if access was denied, `events` comes back
                // empty and `hadMeeting` is simply false.
                let events = eventKitClient.events(from: hourStart, to: hourEnd)
                let hadMeeting = Self.hasMeeting(events: events, hourStart: hourStart, calendar: calendar)

                let url = ActivityLog.url(for: now, calendar: calendar)
                let rows = ActivityLog.upsert(
                    ActivityLog.load(from: url),
                    key: key,
                    activeDelta: isActive ? pollInterval : 0,
                    observedDelta: pollInterval,
                    hadMeeting: hadMeeting
                )
                ActivityLog.save(rows, to: url)

                try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    /// Local calendar day + hour for `date`.
    static func bucketKey(for date: Date, calendar: Calendar = .current) -> ActivityLogKey {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let day = formatter.string(from: date)
        let hour = calendar.component(.hour, from: date)
        return ActivityLogKey(date: day, hour: hour)
    }

    /// True if any real, attending meeting overlaps `[hourStart, hourStart + 1h)`.
    /// All-day events (they span the whole day, so they'd overlap every
    /// hour) and declined invites are excluded — same filter as
    /// `CalendarFeature.dueReminders`.
    static func hasMeeting(events: [EventInfo], hourStart: Date, calendar: Calendar = .current) -> Bool {
        let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart) ?? hourStart.addingTimeInterval(3600)
        return events.contains {
            !$0.isAllDay && !$0.isDeclined && $0.start < hourEnd && $0.end > hourStart
        }
    }
}
