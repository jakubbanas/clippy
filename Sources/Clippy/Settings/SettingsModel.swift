import Foundation
import Observation

/// State behind the Settings window. Main thread only.
///
/// `config` is always the last *valid* config: toggles and steppers bind to it
/// directly (they cannot produce a bad value), and every change is saved. The
/// fields that can hold a bad value — lead times, hotkey, nudges — are edited
/// as drafts and only copied into `config` once they validate.
@Observable
final class SettingsModel {
    var config: AppConfig {
        didSet { save(config) }
    }
    /// Sorted calendar titles; empty when calendar access is missing.
    let availableCalendars: [String]

    var leadMinutesText: String {
        didSet {
            if let minutes = SettingsValidation.parseLeadMinutes(leadMinutesText) {
                leadMinutesError = nil
                config.calendar.leadMinutes = minutes
            } else {
                leadMinutesError = "Use minutes separated by commas, like 1, 0."
            }
        }
    }

    /// Saved on every keystroke that parses, so typing "cmd shift k" passes
    /// through "cmd s". An invalid text falls back to the hotkey the window
    /// opened with, so no half-typed combo outlives the edit.
    var hotkeyText: String {
        didSet {
            if let combo = HotKeyCombo.parse(hotkeyText), combo.modifiers != 0 {
                hotkeyError = nil
                config.launcher.hotkey = hotkeyText
            } else {
                hotkeyError = "Use a key with modifiers, like ⌥Space."
                if config.launcher.hotkey != originalHotkey { config.launcher.hotkey = originalHotkey }
            }
        }
    }
    @ObservationIgnored private let originalHotkey: String

    var nudges: [NudgeConfig] {
        didSet {
            nudgesError = SettingsValidation.nudgesError(nudges)
            if nudgesError == nil { config.nudges = nudges }
        }
    }

    private(set) var leadMinutesError: String?
    private(set) var hotkeyError: String?
    private(set) var nudgesError: String?
    private(set) var calendarsError: String?

    @ObservationIgnored private let save: (AppConfig) -> Void

    init(config: AppConfig, availableCalendars: [String], save: @escaping (AppConfig) -> Void) {
        self.config = config
        self.availableCalendars = availableCalendars
        self.save = save
        leadMinutesText = config.calendar.leadMinutes
            .map { String(format: "%g", $0) }
            .joined(separator: ", ")
        hotkeyText = config.launcher.hotkey
        originalHotkey = config.launcher.hotkey
        nudges = config.nudges
    }

    /// `calendars == nil` means "all calendars".
    func isCalendarSelected(_ title: String) -> Bool {
        config.calendar.calendars?.contains(title) ?? true
    }

    func setCalendar(_ title: String, selected: Bool) {
        let chosen = availableCalendars.filter { $0 == title ? selected : isCalendarSelected($0) }
        guard !chosen.isEmpty else {
            calendarsError = "Pick at least one calendar, or turn reminders off."
            return
        }
        calendarsError = nil
        // All checked is stored as nil, so calendars added later are watched too.
        config.calendar.calendars = chosen.count == availableCalendars.count ? nil : chosen
    }
}

enum SettingsValidation {
    /// "1, 0" → [1, 0]. Spaces and empty pieces (a trailing comma) are ignored;
    /// every remaining piece must be a number ≥ 0, and at least one must exist.
    static func parseLeadMinutes(_ text: String) -> [Double]? {
        let pieces = text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let values = pieces.compactMap(Double.init)
        guard !values.isEmpty, values.count == pieces.count, values.allSatisfy({ $0 >= 0 }) else { return nil }
        return values
    }

    /// Names must be non-empty and unique: `NudgesFeature` keys its timers by
    /// name and traps on a duplicate.
    static func nudgesError(_ nudges: [NudgeConfig]) -> String? {
        var seen = Set<String>()
        for nudge in nudges {
            let name = nudge.name.trimmingCharacters(in: .whitespaces)
            if name.isEmpty { return "Every nudge needs a name." }
            if !seen.insert(name).inserted { return "Two nudges are named \"\(name)\"." }
        }
        return nil
    }
}
