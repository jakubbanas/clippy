import Foundation

/// One thing you mean to get done. Order in the list is the priority order —
/// there are no dates: an item lives until you delete it.
struct Priority: Codable, Equatable {
    /// A UUID string, stable across edits, used to address a row from the menu.
    let id: String
    var text: String
    var done: Bool
}

/// Pure JSONL model for the priorities list, mirroring `ClipboardStore`:
/// `add`/`toggle`/`remove`/`serialize`/`parse` are value transforms, disk I/O is
/// isolated to `load`/`save`, and writes go through a temp file + atomic replace.
///
/// JSONL rather than CSV for the same reason clipboard history uses it: the text
/// is arbitrary user input, JSON escaping handles quotes and newlines for free,
/// and one malformed line cannot cost you the rest of the list.
enum PriorityStore {
    static var url: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.jbanas.clippy/priorities.jsonl")
    }

    /// Appends to the end — new items are the least urgent until you reorder by
    /// deleting and re-adding. Blank text is ignored rather than added as an
    /// empty row.
    static func add(_ priorities: [Priority], text: String, id: String = UUID().uuidString) -> [Priority] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return priorities }
        return priorities + [Priority(id: id, text: trimmed, done: false)]
    }

    /// Flips the done flag. A done item stays on the list — clearing it is a
    /// separate, explicit `remove`.
    static func toggle(_ priorities: [Priority], id: String) -> [Priority] {
        priorities.map { $0.id == id ? Priority(id: $0.id, text: $0.text, done: !$0.done) : $0 }
    }

    static func remove(_ priorities: [Priority], id: String) -> [Priority] {
        priorities.filter { $0.id != id }
    }

    static func serialize(_ priorities: [Priority]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys] // never .prettyPrinted — one line per priority
        let lines = priorities.compactMap { priority -> String? in
            guard let data = try? encoder.encode(priority) else { return nil }
            return String(data: data, encoding: .utf8)
        }
        return lines.isEmpty ? "" : lines.joined(separator: "\n") + "\n"
    }

    /// Skips unparseable lines rather than failing the whole read, matching
    /// `ClipboardStore.parse`.
    static func parse(_ jsonl: String) -> [Priority] {
        let decoder = JSONDecoder()
        return jsonl.split(separator: "\n", omittingEmptySubsequences: true).compactMap { line in
            guard let data = line.data(using: .utf8) else { return nil }
            return try? decoder.decode(Priority.self, from: data)
        }
    }

    static func load(from url: URL = PriorityStore.url) -> [Priority] {
        guard let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) else {
            return []
        }
        return parse(text)
    }

    /// Temp file + atomic replace, like `ActivityLog.save` — a crash mid-write
    /// leaves the previous list intact rather than a truncated one.
    static func save(_ priorities: [Priority], to url: URL = PriorityStore.url) {
        guard let data = serialize(priorities).data(using: .utf8) else { return }
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let tempURL = directory.appendingPathComponent(UUID().uuidString + ".tmp")
        do {
            try data.write(to: tempURL)
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
        } catch {
            // replaceItemAt requires url to already exist; fall back to a plain
            // move for the first-ever write, same as ActivityLog.save.
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.moveItem(at: tempURL, to: url)
        }
    }
}
