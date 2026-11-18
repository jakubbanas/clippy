import Foundation

/// One captured clipboard entry.
struct Clip: Codable, Equatable {
    /// `timeIntervalSince1970`.
    let copiedAt: Double
    /// The app that was frontmost when this was copied, for the row subtitle.
    let app: String?
    let text: String
}

/// Pure JSONL model for clipboard history, mirroring `ActivityLog`'s split:
/// `serialize`/`parse`/`record` are value transforms, disk I/O is isolated to
/// `load`/`save`, and writes go through a temp file + atomic replace.
///
/// JSONL rather than ActivityLog's CSV because clip text contains newlines,
/// commas and quotes; JSON escaping handles those for free, and one malformed
/// line cannot corrupt the rest of the file.
///
/// One file rather than ActivityLog's monthly rotation: search covers all
/// history, so rotation would mean loading and merging N files per keystroke.
///
/// Clips are newest-first everywhere — in memory, on disk, and in `record`'s
/// return value.
enum ClipboardStore {
    static var url: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.jbanas.clippy/clipboard.jsonl")
    }

    /// Prepends `clip`. An exact text duplicate anywhere in the list moves to
    /// the top with the new timestamp instead of duplicating — re-copying the
    /// same string should not flood the history. Trims to `maxItems`.
    static func record(_ clips: [Clip], clip: Clip, maxItems: Int) -> [Clip] {
        var clips = clips.filter { $0.text != clip.text }
        clips.insert(clip, at: 0)
        if clips.count > maxItems { clips = Array(clips.prefix(maxItems)) }
        return clips
    }

    /// Pins live in their own file, written only on pin/unpin, so trimming and
    /// the per-copy rewrite of `url` can never touch them.
    static var pinnedURL: URL {
        url.deletingLastPathComponent().appendingPathComponent("pinned.jsonl")
    }

    /// Prepends `clip`, dropping any existing pin with the same text. No limit.
    static func pin(_ pins: [Clip], clip: Clip) -> [Clip] {
        [clip] + unpin(pins, text: clip.text)
    }

    static func unpin(_ pins: [Clip], text: String) -> [Clip] {
        pins.filter { $0.text != text }
    }

    /// History without the texts already shown as pins, so each text appears once.
    static func unpinnedHistory(_ history: [Clip], pins: [Clip]) -> [Clip] {
        let pinned = Set(pins.map(\.text))
        return history.filter { !pinned.contains($0.text) }
    }

    static func serialize(_ clips: [Clip]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys] // never .prettyPrinted — one line per clip
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let lines = clips.compactMap { clip -> String? in
            guard let data = try? encoder.encode(clip) else { return nil }
            return String(data: data, encoding: .utf8)
        }
        return lines.isEmpty ? "" : lines.joined(separator: "\n") + "\n"
    }

    /// Skips unparseable lines rather than failing the whole read, matching
    /// `ActivityLog.parse` — a single bad line must not cost you the history.
    static func parse(_ jsonl: String) -> [Clip] {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return jsonl.split(separator: "\n", omittingEmptySubsequences: true).compactMap { line in
            guard let data = line.data(using: .utf8) else { return nil }
            return try? decoder.decode(Clip.self, from: data)
        }
    }

    static func load(from url: URL) -> [Clip] {
        guard let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) else {
            return []
        }
        return parse(text)
    }

    /// Temp file + atomic replace, like `ActivityLog.save`, with one addition:
    /// mode `0600` is set on the temp file BEFORE the replace. Writing at the
    /// default umask first would leave the user's clipboard world-readable, and
    /// `replaceItemAt` carries the temp file's attributes over.
    static func save(_ clips: [Clip], to url: URL) {
        guard let data = serialize(clips).data(using: .utf8) else { return }
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let tempURL = directory.appendingPathComponent(UUID().uuidString + ".tmp")
        do {
            try data.write(to: tempURL)
            try FileManager.default.setAttributes(
                [.posixPermissions: NSNumber(value: Int16(0o600))], ofItemAtPath: tempURL.path
            )
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
        } catch {
            // replaceItemAt requires url to already exist; fall back to a plain
            // move for the first-ever write, same as ActivityLog.save.
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.moveItem(at: tempURL, to: url)
        }
        // Belt and braces: replaceItemAt does not guarantee the temp file's mode
        // survives on every filesystem, and this file is the user's clipboard.
        try? FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o600))], ofItemAtPath: url.path
        )
    }
}
