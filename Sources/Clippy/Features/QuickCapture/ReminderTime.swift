import Foundation

/// Parses the capture panel's short time field into an absolute fire date.
///
/// Relative: `20m`, `2h`, `3d`. Absolute: `3pm`, `9:30am`, `15:00`.
/// An absolute time already past today rolls to the same time tomorrow.
/// Returns nil for anything unparseable, so the panel can reject it.
enum ReminderTime {
    static func parse(_ input: String, now: Date, calendar: Calendar = .current) -> Date? {
        let s = input.trimmingCharacters(in: .whitespaces).lowercased()
        guard !s.isEmpty else { return nil }
        return parseRelative(s, now: now) ?? parseAbsolute(s, now: now, calendar: calendar)
    }

    /// `<number><unit>` where unit is minutes / hours / days.
    private static func parseRelative(_ s: String, now: Date) -> Date? {
        let digits = String(s.prefix(while: \.isNumber))
        guard !digits.isEmpty, let n = Double(digits) else { return nil }
        let unit = s.dropFirst(digits.count).trimmingCharacters(in: .whitespaces)
        switch unit {
        case "m", "min", "mins", "minute", "minutes": return now.addingTimeInterval(n * 60)
        case "h", "hr", "hrs", "hour", "hours": return now.addingTimeInterval(n * 3600)
        case "d", "day", "days": return now.addingTimeInterval(n * 86400)
        default: return nil
        }
    }

    /// `h[:mm][am|pm]` (12-hour) or `HH:mm` (24-hour). Rolls to tomorrow if past.
    private static func parseAbsolute(_ s: String, now: Date, calendar: Calendar) -> Date? {
        var body = s
        var ampm: String?
        if body.hasSuffix("am") { ampm = "am"; body.removeLast(2) }
        else if body.hasSuffix("pm") { ampm = "pm"; body.removeLast(2) }
        body = body.trimmingCharacters(in: .whitespaces)

        let parts = body.split(separator: ":", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count), var hour = Int(parts[0]) else { return nil }
        let minute = parts.count == 2 ? Int(parts[1]) : 0
        guard let minute, (0..<60).contains(minute) else { return nil }

        if let ampm {
            guard (1...12).contains(hour) else { return nil }
            if ampm == "pm" && hour != 12 { hour += 12 }
            if ampm == "am" && hour == 12 { hour = 0 }
        } else {
            guard hour <= 23 else { return nil }
        }

        var comps = calendar.dateComponents([.year, .month, .day], from: now)
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        guard let candidate = calendar.date(from: comps) else { return nil }
        return candidate <= now ? calendar.date(byAdding: .day, value: 1, to: candidate) : candidate
    }
}
