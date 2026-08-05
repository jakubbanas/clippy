import Foundation

/// One hour's bucket, keyed by local calendar day + hour.
struct ActivityLogKey: Hashable {
    let date: String // "yyyy-MM-dd", local time
    let hour: Int     // 0-23, local time
}

struct ActivityLogRow: Equatable {
    var activeSeconds: Double
    var observedSeconds: Double
    var hadMeeting: Bool
}

/// Pure CSV model for the activity log: one file per month, one row per
/// hour. Disk I/O is isolated to `load`/`save`; everything else is a plain
/// value transform, testable without touching disk.
enum ActivityLog {
    /// Path to the CSV for the month containing `date`, e.g.
    /// `~/Library/Application Support/com.jbanas.clippy/activity-2026-08.csv`.
    /// Computed fresh from `date` every call, so a run spanning a month
    /// boundary starts writing to the new month's file with no restart.
    static func url(for date: Date, calendar: Calendar = .current) -> URL {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM"
        let month = formatter.string(from: date)
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.jbanas.clippy/activity-\(month).csv")
    }

    /// Adds the active/observed deltas to any existing row for `key` (or
    /// creates one), and overwrites `hadMeeting` with the latest value —
    /// a fresh calendar check each poll is authoritative, so it's never
    /// OR'd with a stale prior value.
    static func upsert(
        _ rows: [ActivityLogKey: ActivityLogRow],
        key: ActivityLogKey,
        activeDelta: Double,
        observedDelta: Double,
        hadMeeting: Bool
    ) -> [ActivityLogKey: ActivityLogRow] {
        var rows = rows
        var row = rows[key] ?? ActivityLogRow(activeSeconds: 0, observedSeconds: 0, hadMeeting: false)
        row.activeSeconds += activeDelta
        row.observedSeconds += observedDelta
        row.hadMeeting = hadMeeting
        rows[key] = row
        return rows
    }

    /// Serializes rows to CSV text (header + one line per row), sorted by
    /// date then hour for stable, diffable output.
    static func serialize(_ rows: [ActivityLogKey: ActivityLogRow]) -> String {
        var lines = ["date,hour,active_seconds,observed_seconds,had_meeting"]
        let sortedKeys = rows.keys.sorted {
            $0.date == $1.date ? $0.hour < $1.hour : $0.date < $1.date
        }
        for key in sortedKeys {
            guard let row = rows[key] else { continue }
            lines.append("\(key.date),\(key.hour),\(row.activeSeconds),\(row.observedSeconds),\(row.hadMeeting)")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Parses CSV text back into a rows dictionary. Skips the header and
    /// any malformed lines rather than failing the whole parse.
    static func parse(_ csv: String) -> [ActivityLogKey: ActivityLogRow] {
        var rows: [ActivityLogKey: ActivityLogRow] = [:]
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: true)
        for line in lines.dropFirst() {
            let fields = line.split(separator: ",")
            guard fields.count == 5,
                  let hour = Int(fields[1]),
                  let active = Double(fields[2]),
                  let observed = Double(fields[3]) else { continue }
            let key = ActivityLogKey(date: String(fields[0]), hour: hour)
            rows[key] = ActivityLogRow(activeSeconds: active, observedSeconds: observed, hadMeeting: fields[4] == "true")
        }
        return rows
    }

    /// Loads the rows for `url`, or an empty dict if the file doesn't
    /// exist yet or can't be parsed.
    static func load(from url: URL) -> [ActivityLogKey: ActivityLogRow] {
        guard let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) else {
            return [:]
        }
        return parse(text)
    }

    /// Writes rows to `url` via a temp file + atomic replace, so a crash
    /// mid-write can't corrupt the CSV.
    static func save(_ rows: [ActivityLogKey: ActivityLogRow], to url: URL) {
        guard let data = serialize(rows).data(using: .utf8) else { return }
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let tempURL = dir.appendingPathComponent(UUID().uuidString + ".tmp")
        do {
            try data.write(to: tempURL)
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
        } catch {
            // replaceItemAt requires url to already exist; fall back to a
            // plain move for the first-ever write of a given month's file.
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.moveItem(at: tempURL, to: url)
        }
    }
}
