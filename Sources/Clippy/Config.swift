import Foundation

/// App configuration, persisted as JSON in Application Support.
/// Missing keys fall back to defaults, so partial config files are fine.
struct AppConfig: Codable {
    var calendar: CalendarConfig
    var quickCapture: QuickCaptureConfig
    var nudges: [NudgeConfig]

    init(
        calendar: CalendarConfig = CalendarConfig(),
        quickCapture: QuickCaptureConfig = QuickCaptureConfig(),
        nudges: [NudgeConfig] = NudgeConfig.defaults
    ) {
        self.calendar = calendar
        self.quickCapture = quickCapture
        self.nudges = nudges
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        calendar = try container.decodeIfPresent(CalendarConfig.self, forKey: .calendar) ?? CalendarConfig()
        quickCapture = try container.decodeIfPresent(QuickCaptureConfig.self, forKey: .quickCapture) ?? QuickCaptureConfig()
        nudges = try container.decodeIfPresent([NudgeConfig].self, forKey: .nudges) ?? NudgeConfig.defaults
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

/// A recurring reminder to do something (drink water, take a break). Fires every
/// `everyMinutes` while `enabled`.
struct NudgeConfig: Codable, Equatable {
    var name: String
    var enabled: Bool
    var everyMinutes: Double
    var message: String

    static let defaults: [NudgeConfig] = [
        NudgeConfig(name: "Water", enabled: true, everyMinutes: 45, message: "💧 Time for some water!"),
        NudgeConfig(name: "Breaks", enabled: true, everyMinutes: 90, message: "Stretch and rest your eyes for a moment."),
    ]

    init(name: String = "Nudge", enabled: Bool = true, everyMinutes: Double = 60, message: String = "Time for a nudge!") {
        self.name = name
        self.enabled = enabled
        self.everyMinutes = everyMinutes
        self.message = message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Nudge"
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        everyMinutes = try container.decodeIfPresent(Double.self, forKey: .everyMinutes) ?? 60
        message = try container.decodeIfPresent(String.self, forKey: .message) ?? "Time for a nudge!"
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
