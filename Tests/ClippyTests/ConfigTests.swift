import XCTest
@testable import Clippy

final class ConfigTests: XCTestCase {
    private func decode(_ json: String) throws -> AppConfig {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(AppConfig.self, from: Data(json.utf8))
    }

    func testConfigEquality() {
        XCTAssertEqual(AppConfig(), AppConfig())
        var changed = AppConfig()
        changed.clipboard.maxItems = 42
        XCTAssertNotEqual(changed, AppConfig())
    }

    func testSaveThenLoadRoundTrips() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("config.json")
        var config = AppConfig()
        config.launcher.hotkey = "cmd shift r"
        config.nudges = [NudgeConfig(name: "Tea", enabled: false, everyMinutes: 30, message: "Tea?")]
        config.calendar.calendars = ["Work"]
        ConfigStore.save(config, to: url)
        XCTAssertEqual(ConfigStore.load(from: url), config)
    }

    /// Opening Settings loads the config; a typo must not cost the user their file.
    func testLoadLeavesABrokenFileAlone() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("config.json")
        try Data(#"{ "launcher": { "hotkey": "cmd k" "#.utf8).write(to: url)
        XCTAssertEqual(ConfigStore.load(from: url), AppConfig())
        XCTAssertEqual(try String(contentsOf: url), #"{ "launcher": { "hotkey": "cmd k" "#)
    }

    func testEmptyJSONGivesDefaults() throws {
        let config = try decode("{}")
        XCTAssertTrue(config.calendar.enabled)
        XCTAssertEqual(config.calendar.leadMinutes, [1, 0])
        XCTAssertNil(config.calendar.calendars)
    }

    func testPartialCalendarConfigKeepsOtherDefaults() throws {
        let config = try decode(#"{ "calendar": { "lead_minutes": [5] } }"#)
        XCTAssertEqual(config.calendar.leadMinutes, [5])
        XCTAssertTrue(config.calendar.enabled)
    }

    func testFullCalendarConfig() throws {
        let config = try decode(#"{ "calendar": { "enabled": false, "lead_minutes": [2, 0], "calendars": ["Work"] } }"#)
        XCTAssertFalse(config.calendar.enabled)
        XCTAssertEqual(config.calendar.leadMinutes, [2, 0])
        XCTAssertEqual(config.calendar.calendars, ["Work"])
    }

    func testBreakTrackerDefaults() throws {
        let config = try decode("{}")
        XCTAssertTrue(config.breakTracker.enabled)
        XCTAssertEqual(config.breakTracker.minBreakMinutes, 15)
    }

    func testPartialBreakTrackerKeepsDefaults() throws {
        let config = try decode(#"{ "break_tracker": { "min_break_minutes": 30 } }"#)
        XCTAssertEqual(config.breakTracker.minBreakMinutes, 30)
        XCTAssertTrue(config.breakTracker.enabled)
    }

    func testLauncherDefaultsAndOverride() throws {
        XCTAssertEqual(try decode("{}").launcher.hotkey, "⌥Space")
        XCTAssertEqual(try decode(#"{ "launcher": { "hotkey": "cmd shift space" } }"#).launcher.hotkey, "cmd shift space")
    }

    func testNudgesDefaultToWaterAndBreaks() throws {
        let config = try decode("{}")
        XCTAssertEqual(config.nudges.map(\.name), ["Water", "Breaks"])
        XCTAssertTrue(config.nudges.allSatisfy(\.enabled))
        XCTAssertEqual(config.nudges.map(\.everyMinutes), [45, 90])
    }

    func testCustomNudgesUsedVerbatim() throws {
        let config = try decode(#"{ "nudges": [{ "name": "Water", "enabled": false, "every_minutes": 30, "message": "hi" }] }"#)
        XCTAssertEqual(config.nudges.count, 1)
        XCTAssertEqual(config.nudges[0], NudgeConfig(name: "Water", enabled: false, everyMinutes: 30, message: "hi"))
    }

    func testPartialNudgeKeepsPerKeyDefaults() throws {
        let config = try decode(#"{ "nudges": [{ "name": "Water", "enabled": false }] }"#)
        XCTAssertEqual(config.nudges[0].everyMinutes, 60)
        XCTAssertEqual(config.nudges[0].message, "Time for a nudge!")
        XCTAssertFalse(config.nudges[0].enabled)
    }

    func testFocusDefaults() throws {
        let config = try decode("{}")
        XCTAssertTrue(config.focus.enabled)
        XCTAssertEqual(config.focus.defaultMinutes, 25)
        XCTAssertTrue(config.focus.midCheckIn)
    }

    func testPartialFocusKeepsDefaults() throws {
        let config = try decode(#"{ "focus": { "default_minutes": 50, "mid_check_in": true } }"#)
        XCTAssertEqual(config.focus.defaultMinutes, 50)
        XCTAssertTrue(config.focus.midCheckIn)
        XCTAssertTrue(config.focus.enabled)
    }

    func testActivityLogDefaults() throws {
        let config = try decode("{}")
        XCTAssertFalse(config.activityLog.enabled)
        XCTAssertEqual(config.activityLog.idleThresholdSeconds, 30)
    }

    func testPartialActivityLogKeepsDefaults() throws {
        let config = try decode(#"{ "activity_log": { "enabled": true } }"#)
        XCTAssertTrue(config.activityLog.enabled)
        XCTAssertEqual(config.activityLog.idleThresholdSeconds, 30)
    }

    func testFullActivityLogConfig() throws {
        let config = try decode(#"{ "activity_log": { "enabled": true, "idle_threshold_seconds": 45 } }"#)
        XCTAssertTrue(config.activityLog.enabled)
        XCTAssertEqual(config.activityLog.idleThresholdSeconds, 45)
    }

    func testAppLauncherDefaultsWhenKeyIsAbsent() throws {
        XCTAssertTrue(try decode("{}").appLauncher.enabled)
    }

    func testAppLauncherCanBeDisabled() throws {
        XCTAssertFalse(try decode(#"{ "app_launcher": { "enabled": false } }"#).appLauncher.enabled)
    }

    func testClipboardDefaultsWhenKeyIsAbsent() throws {
        let config = try decode("{}")
        XCTAssertTrue(config.clipboard.enabled)
        XCTAssertEqual(config.clipboard.maxItems, 500)
    }

    func testClipboardHonorsAPartialConfig() throws {
        let config = try decode(#"{ "clipboard": { "max_items": 10 } }"#)
        XCTAssertEqual(config.clipboard.maxItems, 10)
        XCTAssertTrue(config.clipboard.enabled, "an absent key keeps its default")
    }
}
