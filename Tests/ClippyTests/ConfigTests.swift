import XCTest
@testable import Clippy

final class ConfigTests: XCTestCase {
    private func decode(_ json: String) throws -> AppConfig {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(AppConfig.self, from: Data(json.utf8))
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
}
