import Foundation
import Observation
import ServiceManagement

/// Everything the status-bar popover shows, plus the actions it can trigger.
/// The actions are closures wired by `AppDelegate`, so the model never
/// touches features, the presenter, or the login-item service directly.
/// Main thread only.
@Observable
final class PopoverModel {
    enum Tab: CaseIterable {
        case activity
        case controls
    }

    var selectedTab: Tab = .activity
    private(set) var week: [DayStat] = []
    private(set) var day: [HourStat] = []
    /// Whole-week active share, weighted by observed time; nil if no data.
    private(set) var weekPercent: Double?
    private(set) var isClippyHidden = false
    private(set) var startsAtLogin = false

    @ObservationIgnored var onTestClippy: () -> Void = {}
    @ObservationIgnored var onSetClippyHidden: (Bool) -> Void = { _ in }
    /// Applies the change and returns the state actually in effect afterwards.
    @ObservationIgnored var onSetStartsAtLogin: (Bool) -> Bool = { $0 }
    @ObservationIgnored var onOpenSettings: () -> Void = {}
    @ObservationIgnored var onQuit: () -> Void = {}

    func setClippyHidden(_ hidden: Bool) {
        isClippyHidden = hidden
        onSetClippyHidden(hidden)
    }

    func setStartsAtLogin(_ enabled: Bool) {
        startsAtLogin = onSetStartsAtLogin(enabled)
    }

    /// Reloads activity stats and the login-item state. Called right before
    /// the popover shows, since the popover lives for the app's whole run —
    /// data would go stale if only computed once.
    func refresh(now: Date = Date(), calendar: Calendar = .current) {
        let dayRows = ActivityLog.load(from: ActivityLog.url(for: now, calendar: calendar))
        day = ActivityLog.dayStats(from: dayRows, for: now, calendar: calendar)

        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) ?? DateInterval(start: now, duration: 0)
        let weekEnd = calendar.date(byAdding: .second, value: -1, to: weekInterval.end) ?? weekInterval.start
        let startURL = ActivityLog.url(for: weekInterval.start, calendar: calendar)
        let endURL = ActivityLog.url(for: weekEnd, calendar: calendar)
        var weekRows = ActivityLog.load(from: startURL)
        if endURL != startURL {
            weekRows.merge(ActivityLog.load(from: endURL)) { _, new in new }
        }
        week = ActivityLog.weekStats(from: weekRows, for: now, calendar: calendar)
        weekPercent = ActivityLog.weekPercent(from: weekRows, for: now, calendar: calendar)

        startsAtLogin = SMAppService.mainApp.status == .enabled
    }
}
