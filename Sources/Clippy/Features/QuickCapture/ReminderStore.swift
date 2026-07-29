import Foundation

/// A one-shot quick-capture reminder. Fires once at `fireAt`, then is deleted —
/// deletion is both the "done" marker and the dedupe (a gone reminder can't re-fire).
struct Reminder: Codable, Equatable {
    let id: UUID
    let text: String
    var fireAt: Date

    init(id: UUID = UUID(), text: String, fireAt: Date) {
        self.id = id
        self.text = text
        self.fireAt = fireAt
    }
}

/// Thread-safe persistence for quick-capture reminders (the I/O isolation layer,
/// analogous to `EventKitClient`). All reads/mutations go through a lock so the
/// poll task and the main-thread capture callback can touch reminders safely.
/// Nothing outside this file reads or writes `reminders.json`.
final class ReminderStore {
    static var defaultURL: URL {
        ConfigStore.url.deletingLastPathComponent().appendingPathComponent("reminders.json")
    }

    private let url: URL
    private let lock = NSLock()
    private var reminders: [Reminder]

    init(url: URL = ReminderStore.defaultURL) {
        self.url = url
        self.reminders = Self.read(from: url)
    }

    func all() -> [Reminder] {
        lock.lock(); defer { lock.unlock() }
        return reminders
    }

    func add(_ reminder: Reminder) {
        lock.lock(); defer { lock.unlock() }
        reminders.append(reminder)
        write()
    }

    func remove(id: UUID) {
        lock.lock(); defer { lock.unlock() }
        reminders.removeAll { $0.id == id }
        write()
    }

    /// Caller must hold `lock`.
    private func write() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(reminders) else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: url)
    }

    private static func read(from url: URL) -> [Reminder] {
        guard let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([Reminder].self, from: data) else { return [] }
        return list
    }
}
