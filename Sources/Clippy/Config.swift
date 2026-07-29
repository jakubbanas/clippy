import Foundation

/// App configuration, persisted as JSON in Application Support.
/// Missing keys fall back to defaults, so partial config files are fine.
struct AppConfig: Codable {
    var calendar: CalendarConfig
    var quickCapture: QuickCaptureConfig

    init(calendar: CalendarConfig = CalendarConfig(), quickCapture: QuickCaptureConfig = QuickCaptureConfig()) {
        self.calendar = calendar
        self.quickCapture = quickCapture
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        calendar = try container.decodeIfPresent(CalendarConfig.self, forKey: .calendar) ?? CalendarConfig()
        quickCapture = try container.decodeIfPresent(QuickCaptureConfig.self, forKey: .quickCapture) ?? QuickCaptureConfig()
    }
}

struct CalendarConfig: Codable {
    var enabled: Bool
    /// Minutes before event start to announce; 0 = at start.
    var leadMinutes: [Double]
    /// Calendar titles to watch; nil = all calendars.
    var calendars: [String]?

    init(enabled: Bool = true, leadMinutes: [Double] = [1, 0], calendars: [String]? = nil) {
        self.enabled = enabled
        self.leadMinutes = leadMinutes
        self.calendars = calendars
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        leadMinutes = try container.decodeIfPresent([Double].self, forKey: .leadMinutes) ?? [1, 0]
        calendars = try container.decodeIfPresent([String].self, forKey: .calendars)
    }
}

struct QuickCaptureConfig: Codable {
    var enabled: Bool
    /// Global hotkey that opens the capture panel, e.g. "⌥Space" or "cmd shift r".
    var hotkey: String
    /// Minutes the Snooze action bumps a fired reminder forward.
    var snoozeMinutes: Double

    init(enabled: Bool = true, hotkey: String = "⌥Space", snoozeMinutes: Double = 10) {
        self.enabled = enabled
        self.hotkey = hotkey
        self.snoozeMinutes = snoozeMinutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        hotkey = try container.decodeIfPresent(String.self, forKey: .hotkey) ?? "⌥Space"
        snoozeMinutes = try container.decodeIfPresent(Double.self, forKey: .snoozeMinutes) ?? 10
    }
}

enum ConfigStore {
    static var url: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.jbanas.clippy/config.json")
    }

    /// Loads config, writing a default file on first run so the user has
    /// something to edit via the tray's "Open Config" item.
    static func load() -> AppConfig {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        if let data = try? Data(contentsOf: url),
           let config = try? decoder.decode(AppConfig.self, from: data) {
            return config
        }
        let config = AppConfig()
        save(config)
        return config
    }

    private static func save(_ config: AppConfig) {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(config) else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: url)
    }
}
