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
}
