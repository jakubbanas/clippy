import Foundation

/// App configuration, persisted as JSON in Application Support.
/// Missing keys fall back to defaults, so partial config files are fine.
struct AppConfig: Codable {
    var calendar: CalendarConfig
    var nudges: [NudgeConfig]
    var focus: FocusConfig
    var breakTracker: BreakTrackerConfig
    var launcher: LauncherConfig
    var activityLog: ActivityLogConfig

    init(
        calendar: CalendarConfig = CalendarConfig(),
        nudges: [NudgeConfig] = NudgeConfig.defaults,
        focus: FocusConfig = FocusConfig(),
        breakTracker: BreakTrackerConfig = BreakTrackerConfig(),
        launcher: LauncherConfig = LauncherConfig(),
        activityLog: ActivityLogConfig = ActivityLogConfig()
    ) {
        self.calendar = calendar
        self.nudges = nudges
        self.focus = focus
        self.breakTracker = breakTracker
        self.launcher = launcher
        self.activityLog = activityLog
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        calendar = try container.decodeIfPresent(CalendarConfig.self, forKey: .calendar) ?? CalendarConfig()
        nudges = try container.decodeIfPresent([NudgeConfig].self, forKey: .nudges) ?? NudgeConfig.defaults
        focus = try container.decodeIfPresent(FocusConfig.self, forKey: .focus) ?? FocusConfig()
        breakTracker = try container.decodeIfPresent(BreakTrackerConfig.self, forKey: .breakTracker) ?? BreakTrackerConfig()
        launcher = try container.decodeIfPresent(LauncherConfig.self, forKey: .launcher) ?? LauncherConfig()
        activityLog = try container.decodeIfPresent(ActivityLogConfig.self, forKey: .activityLog) ?? ActivityLogConfig()
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

/// Silent background logging of active-vs-idle time and meeting overlap,
/// one row per hour, to a monthly CSV. Off by default since it persists
/// granular at-the-keyboard data continuously.
struct ActivityLogConfig: Codable {
    var enabled: Bool
    /// Idle seconds below which a poll counts as "active". Must be >= the
    /// feature's 15s poll interval, or continuous activity gets under-counted.
    var idleThresholdSeconds: Double

    init(enabled: Bool = false, idleThresholdSeconds: Double = 30) {
        self.enabled = enabled
        self.idleThresholdSeconds = idleThresholdSeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        idleThresholdSeconds = try container.decodeIfPresent(Double.self, forKey: .idleThresholdSeconds) ?? 30
    }
}

/// "Welcome back" break tracking — reports how long you were away when you return.
struct BreakTrackerConfig: Codable {
    var enabled: Bool
    /// Don't announce breaks shorter than this.
    var minBreakMinutes: Double

    init(enabled: Bool = true, minBreakMinutes: Double = 15) {
        self.enabled = enabled
        self.minBreakMinutes = minBreakMinutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        minBreakMinutes = try container.decodeIfPresent(Double.self, forKey: .minBreakMinutes) ?? 15
    }
}

/// The single hotkey that opens the command launcher menu.
struct LauncherConfig: Codable {
    var hotkey: String

    init(hotkey: String = "⌥Space") {
        self.hotkey = hotkey
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hotkey = try container.decodeIfPresent(String.self, forKey: .hotkey) ?? "⌥Space"
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

/// A body-doubling focus session: declare a goal, work a timed block, get a
/// check-out prompt at the end.
struct FocusConfig: Codable {
    var enabled: Bool
    /// Pre-filled block length in the start panel.
    var defaultMinutes: Double
    /// Pop a gentle "still on it?" at the halfway point (only for blocks ≥ 20 min).
    var midCheckIn: Bool

    init(enabled: Bool = true, defaultMinutes: Double = 25, midCheckIn: Bool = true) {
        self.enabled = enabled
        self.defaultMinutes = defaultMinutes
        self.midCheckIn = midCheckIn
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        defaultMinutes = try container.decodeIfPresent(Double.self, forKey: .defaultMinutes) ?? 25
        midCheckIn = try container.decodeIfPresent(Bool.self, forKey: .midCheckIn) ?? true
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
