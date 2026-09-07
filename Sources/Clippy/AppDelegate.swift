import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var presenter: Presenter!
    private var announcer: Announcer!
    private var features: [Feature] = []
    private let launcher = CommandLauncher()
    private var loginItem: NSMenuItem!
    private var hideClippyItem: NSMenuItem!
    private var isClippyHidden = false
    private let activityChartView = ActivityStatsView(frame: NSRect(x: 0, y: 0, width: 320, height: 260))
    private let priorityListView = PriorityListView(frame: NSRect(x: 0, y: 0, width: PriorityListView.width, height: 60))
    private lazy var priorityInputWindow: PriorityInputWindow = {
        let window = PriorityInputWindow()
        window.onAdd = { text in
            PriorityStore.save(PriorityStore.add(PriorityStore.load(), text: text))
        }
        return window
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let assets = try ClippyAssets.load()
            let window = ClippyWindow(agent: assets.data, sheet: assets.sheet)
            presenter = Presenter(window: window)
        } catch {
            NSLog("Failed to load Clippy assets: \(error)")
            NSApp.terminate(nil)
            return
        }

        announcer = Announcer(
            deliver: { [presenter] announcement in presenter?.enqueue(announcement) },
            deliverStatus: { [presenter] text, progress in presenter?.setStatus(text, progress: progress) }
        )

        setUpStatusItem()
        features = Registry.builtInFeatures()
        startFeatures()
    }

    private func startFeatures() {
        let config = ConfigStore.load()
        let context = FeatureContext(announcer: announcer, config: config)
        for feature in features {
            feature.start(context: context)
        }
        launcher.configure(hotkey: config.launcher.hotkey, features: features)
    }

    private func reloadFeatures() {
        launcher.stop()
        features.forEach { $0.stop() }
        startFeatures()
    }

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.title = "📎"

        let menu = NSMenu()
        menu.delegate = self
        wirePriorityList()
        let priorityItem = NSMenuItem()
        priorityItem.view = priorityListView
        menu.addItem(priorityItem)
        let addPriorityItem = NSMenuItem(title: "Add priority…", action: #selector(addPriority), keyEquivalent: "n")
        addPriorityItem.target = self
        menu.addItem(addPriorityItem)
        menu.addItem(.separator())
        let activityItem = NSMenuItem()
        activityItem.view = activityChartView
        activityItem.isEnabled = false
        menu.addItem(activityItem)
        menu.addItem(.separator())
        let testItem = NSMenuItem(title: "Test Clippy", action: #selector(testClippy), keyEquivalent: "t")
        testItem.target = self
        menu.addItem(testItem)
        menu.addItem(.separator())
        let configItem = NSMenuItem(title: "Open Config", action: #selector(openConfig), keyEquivalent: "")
        configItem.target = self
        menu.addItem(configItem)
        let reloadItem = NSMenuItem(title: "Reload Config", action: #selector(reloadConfig), keyEquivalent: "")
        reloadItem.target = self
        menu.addItem(reloadItem)
        hideClippyItem = NSMenuItem(title: "Hide Clippy", action: #selector(toggleClippyVisibility), keyEquivalent: "")
        hideClippyItem.target = self
        menu.addItem(hideClippyItem)
        loginItem = NSMenuItem(title: "Start at Login", action: #selector(toggleLoginItem), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Clippy", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    /// Clicking a priority hands its text to the focus feature as the session
    /// goal, at the configured default length — one click from "this matters"
    /// to a running block.
    private func wirePriorityList() {
        priorityListView.onStart = { [weak self] priority in
            self?.statusItem.menu?.cancelTracking()
            let focus = self?.features.compactMap { $0 as? FocusSessionFeature }.first
            focus?.startSession(goal: priority.text)
        }
        priorityListView.onToggle = { [weak self] priority in
            let priorities = PriorityStore.toggle(PriorityStore.load(), id: priority.id)
            PriorityStore.save(priorities)
            // Same row count, so the open menu keeps its size — safe to redraw
            // in place rather than close.
            self?.priorityListView.configure(priorities: priorities)
        }
        priorityListView.onRemove = { [weak self] priority in
            PriorityStore.save(PriorityStore.remove(PriorityStore.load(), id: priority.id))
            // One row shorter: an open menu will not re-lay-out around a
            // smaller view, so close it and show the new list on next open.
            self?.statusItem.menu?.cancelTracking()
        }
    }

    @objc private func addPriority() {
        priorityInputWindow.show()
    }

    @objc private func openConfig() {
        _ = ConfigStore.load() // ensures the file exists before opening
        NSWorkspace.shared.open(ConfigStore.url)
    }

    @objc private func reloadConfig() {
        reloadFeatures()
    }

    /// Recomputes the activity charts right before the menu opens, since the
    /// menu (and its embedded chart view) stays alive for the app's whole
    /// run — data would go stale if only computed once at construction.
    func menuWillOpen(_ menu: NSMenu) {
        priorityListView.configure(priorities: PriorityStore.load())

        let calendar = Calendar.current
        let now = Date()

        let dayRows = ActivityLog.load(from: ActivityLog.url(for: now, calendar: calendar))
        let day = ActivityLog.dayStats(from: dayRows, for: now, calendar: calendar)

        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) ?? DateInterval(start: now, duration: 0)
        let weekEnd = calendar.date(byAdding: .second, value: -1, to: weekInterval.end) ?? weekInterval.start
        let startURL = ActivityLog.url(for: weekInterval.start, calendar: calendar)
        let endURL = ActivityLog.url(for: weekEnd, calendar: calendar)
        var weekRows = ActivityLog.load(from: startURL)
        if endURL != startURL {
            weekRows.merge(ActivityLog.load(from: endURL)) { _, new in new }
        }
        let week = ActivityLog.weekStats(from: weekRows, for: now, calendar: calendar)

        activityChartView.configure(week: week, day: day)
    }

    @objc private func toggleClippyVisibility() {
        isClippyHidden.toggle()
        presenter.setVisible(!isClippyHidden)
        hideClippyItem.title = isClippyHidden ? "Show Clippy" : "Hide Clippy"
    }

    @objc private func toggleLoginItem() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            NSLog("Login item toggle failed: \(error)")
        }
        loginItem.state = service.status == .enabled ? .on : .off
    }

    @objc private func testClippy() {
        announcer.announce(Announcement(
            id: "test:\(Date().timeIntervalSince1970)",
            featureID: "test",
            animation: "Wave",
            title: "It looks like you have a meeting!",
            body: ["10:00 – 10:30", "Standup"],
            actions: [
                AnnouncementAction(label: "Join", kind: .openURL(URL(string: "https://example.com")!)),
                AnnouncementAction(label: "Snooze 5 min", kind: .snooze(300)),
                AnnouncementAction(label: "Dismiss", kind: .dismiss),
            ],
            timeout: 20
        ))
    }
}
