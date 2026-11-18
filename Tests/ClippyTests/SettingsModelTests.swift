import XCTest
@testable import Clippy

final class SettingsModelTests: XCTestCase {
    /// Records every config the model asks to save.
    private final class Saves {
        var all: [AppConfig] = []
    }

    private func makeModel(
        _ config: AppConfig = AppConfig(),
        calendars: [String] = ["Home", "Work"]
    ) -> (SettingsModel, Saves) {
        let saves = Saves()
        let model = SettingsModel(config: config, availableCalendars: calendars) { saves.all.append($0) }
        return (model, saves)
    }

    // MARK: Lead minutes

    func testInitFormatsLeadMinutes() {
        XCTAssertEqual(makeModel().0.leadMinutesText, "1, 0")
        var config = AppConfig()
        config.calendar.leadMinutes = [0.5]
        XCTAssertEqual(makeModel(config).0.leadMinutesText, "0.5")
    }

    func testLeadMinutesToleratesSpacesAndTrailingComma() {
        XCTAssertEqual(SettingsValidation.parseLeadMinutes(" 1, 0, "), [1, 0])
    }

    func testLeadMinutesRejectsBadInput() {
        for bad in ["", "a", "-1", "1,,x", " , "] {
            XCTAssertNil(SettingsValidation.parseLeadMinutes(bad), bad)
        }
    }

    func testValidLeadMinutesSaves() {
        let (model, saves) = makeModel()
        model.leadMinutesText = "5, 0"
        XCTAssertEqual(saves.all.last?.calendar.leadMinutes, [5, 0])
        XCTAssertNil(model.leadMinutesError)
    }

    func testInvalidLeadMinutesIsNotSaved() {
        let (model, saves) = makeModel()
        model.leadMinutesText = "soon"
        XCTAssertTrue(saves.all.isEmpty)
        XCTAssertEqual(model.leadMinutesError, "Use minutes separated by commas, like 1, 0.")
        XCTAssertEqual(model.config.calendar.leadMinutes, [1, 0])
    }

    // MARK: Hotkey

    func testValidHotkeySaves() {
        let (model, saves) = makeModel()
        model.hotkeyText = "cmd shift r"
        XCTAssertEqual(saves.all.last?.launcher.hotkey, "cmd shift r")
        XCTAssertNil(model.hotkeyError)
    }

    func testInvalidHotkeyIsNotSaved() {
        let (model, saves) = makeModel()
        model.hotkeyText = "⌥⌘"
        XCTAssertTrue(saves.all.isEmpty)
        XCTAssertEqual(model.hotkeyError, "Use a key with modifiers, like ⌥Space.")
    }

    /// A bare key would become a system-wide hotkey and stop that key typing anywhere.
    func testHotkeyWithoutModifiersIsNotSaved() {
        let (model, saves) = makeModel()
        model.hotkeyText = "c"
        XCTAssertTrue(saves.all.isEmpty)
        XCTAssertNotNil(model.hotkeyError)
    }

    /// Typing "cmd shift k" passes through "cmd s"; an invalid final text must
    /// not leave that half-typed ⌘S registered.
    func testInvalidHotkeyRestoresTheOriginal() {
        let (model, saves) = makeModel()
        model.hotkeyText = "cmd s"
        model.hotkeyText = "cmd shift ;"
        XCTAssertEqual(model.config.launcher.hotkey, "⌥Space")
        XCTAssertEqual(saves.all.last?.launcher.hotkey, "⌥Space")
    }

    // MARK: Clips to keep

    func testValidMaxClipsSaves() {
        let (model, saves) = makeModel()
        XCTAssertEqual(model.maxClipsText, "500")
        model.maxClipsText = " 4000 "
        XCTAssertEqual(saves.all.last?.clipboard.maxItems, 4000)
        XCTAssertNil(model.maxClipsError)
    }

    func testMaxClipsRejectsBadInput() {
        for bad in ["", "abc", "0", "-5", "12.5", "5001"] {
            XCTAssertNil(SettingsValidation.parseMaxClips(bad), bad)
        }
    }

    /// Retyping "4000" over "500" can pass through "4"; leaving the field
    /// invalid must not keep that value, or the next copy trims history to 4.
    func testInvalidMaxClipsRestoresTheOriginal() {
        let (model, _) = makeModel()
        model.maxClipsText = "4"
        model.maxClipsText = ""
        XCTAssertEqual(model.config.clipboard.maxItems, 500)
        XCTAssertEqual(model.maxClipsError, "Use a whole number from 1 to 5000.")
    }

    // MARK: Nudges

    func testDuplicateNudgeNameIsNotSaved() {
        let (model, saves) = makeModel()
        model.nudges[1].name = model.nudges[0].name
        XCTAssertTrue(saves.all.isEmpty)
        XCTAssertEqual(model.nudgesError, "Two nudges are named \"Water\".")
        XCTAssertEqual(model.config.nudges, NudgeConfig.defaults)
    }

    func testEmptyNudgeNameIsNotSaved() {
        let (model, saves) = makeModel()
        model.nudges[0].name = "  "
        XCTAssertTrue(saves.all.isEmpty)
        XCTAssertEqual(model.nudgesError, "Every nudge needs a name.")
    }

    func testRemovingAllNudgesSaves() {
        let (model, saves) = makeModel()
        model.nudges = []
        XCTAssertEqual(saves.all.last?.nudges, [])
        XCTAssertNil(model.nudgesError)
    }

    // MARK: Direct fields

    func testToggleSavesImmediately() {
        let (model, saves) = makeModel()
        model.config.clipboard.enabled = false
        XCTAssertEqual(saves.all.count, 1)
        XCTAssertEqual(saves.all.last?.clipboard.enabled, false)
    }

    // MARK: Calendars

    func testAllCalendarsSelectedWhenNil() {
        XCTAssertTrue(makeModel().0.isCalendarSelected("Work"))
    }

    func testUncheckingCalendarStoresTheRest() {
        let (model, saves) = makeModel()
        model.setCalendar("Work", selected: false)
        XCTAssertEqual(saves.all.last?.calendar.calendars, ["Home"])
        XCTAssertFalse(model.isCalendarSelected("Work"))
    }

    func testCheckingAllCalendarsStoresNil() {
        var config = AppConfig()
        config.calendar.calendars = ["Home"]
        let (model, saves) = makeModel(config)
        model.setCalendar("Work", selected: true)
        XCTAssertEqual(saves.all.count, 1)
        XCTAssertNil(saves.all.last?.calendar.calendars)
    }

    func testCannotUncheckLastCalendar() {
        var config = AppConfig()
        config.calendar.calendars = ["Home"]
        let (model, saves) = makeModel(config)
        model.setCalendar("Home", selected: false)
        XCTAssertTrue(saves.all.isEmpty)
        XCTAssertEqual(model.calendarsError, "Pick at least one calendar, or turn reminders off.")
        XCTAssertTrue(model.isCalendarSelected("Home"))
    }
}
