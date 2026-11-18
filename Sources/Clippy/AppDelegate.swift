import AppKit
import ServiceManagement
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var presenter: Presenter!
    private var announcer: Announcer!
    private var features: [Feature] = []
    private let launcher = CommandLauncher()
    private let popover = NSPopover()
    private let model = PopoverModel()
    /// The config the features were last started with, so closing Settings
    /// can tell whether anything changed.
    private var runningConfig = AppConfig()
    private var settingsWindow: SettingsWindow?

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
        runningConfig = config
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
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)

        wireModel()
        let host = NSHostingController(rootView: PopoverView(model: model))
        // Without this the popover keeps its first size when the tab changes.
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host
        popover.behavior = .transient
        popover.appearance = NSAppearance(named: .darkAqua)
    }

    private func wireModel() {
        model.onTestClippy = { [weak self] in
            self?.popover.performClose(nil)
            self?.testClippy()
        }
        model.onSetClippyHidden = { [weak self] hidden in
            self?.presenter.setVisible(!hidden)
        }
        model.onSetStartsAtLogin = { enabled in
            Self.setStartsAtLogin(enabled)
        }
        model.onOpenSettings = { [weak self] in
            self?.popover.performClose(nil)
            self?.showSettings()
        }
        model.onQuit = {
            NSApp.terminate(nil)
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        model.refresh()
        // An accessory app is never active on its own; without this the
        // transient popover does not close on click-outside reliably.
        NSApp.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    /// A fresh model per opening, so hand edits to config.json show up.
    private func showSettings() {
        // Any live window (visible or minimised) is reused; a second one would
        // edit a stale model and save over the first.
        if let settingsWindow {
            settingsWindow.show()
            return
        }
        let model = SettingsModel(
            config: ConfigStore.load(),
            availableCalendars: EventKitClient().calendarTitles(),
            save: { ConfigStore.save($0) }
        )
        let window = SettingsWindow(model: model)
        window.onClose = { [weak self] in self?.settingsClosed() }
        settingsWindow = window
        window.show()
    }

    /// One reload on close, and only when something changed: a reload restarts
    /// every feature, which ends a running focus session.
    private func settingsClosed() {
        if ConfigStore.load() != runningConfig {
            reloadFeatures()
        }
        // Released on the next turn: this runs inside the window's own
        // windowWillClose, so freeing its delegate here would be premature.
        DispatchQueue.main.async { [weak self] in self?.settingsWindow = nil }
    }

    /// Returns the state actually in effect afterwards, so a failed
    /// (un)registration shows the real state in the toggle.
    private static func setStartsAtLogin(_ enabled: Bool) -> Bool {
        let service = SMAppService.mainApp
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            NSLog("Login item toggle failed: \(error)")
        }
        return service.status == .enabled
    }

    private func testClippy() {
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
