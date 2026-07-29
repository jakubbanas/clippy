import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var presenter: Presenter!
    private var announcer: Announcer!
    private var features: [Feature] = []

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

        announcer = Announcer { [presenter] announcement in
            presenter?.enqueue(announcement)
        }

        setUpStatusItem()

        let context = FeatureContext(announcer: announcer)
        features = Registry.builtInFeatures()
        for feature in features {
            feature.start(context: context)
        }
    }

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.title = "📎"

        let menu = NSMenu()
        let testItem = NSMenuItem(title: "Test Clippy", action: #selector(testClippy), keyEquivalent: "t")
        testItem.target = self
        menu.addItem(testItem)
        let dumpItem = NSMenuItem(title: "Dump Next Events", action: #selector(dumpNextEvents), keyEquivalent: "")
        dumpItem.target = self
        menu.addItem(dumpItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Clippy", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func dumpNextEvents() {
        Task {
            let client = EventKitClient()
            do {
                try await client.requestAccess()
                let now = Date()
                let events = client.events(from: now, to: now.addingTimeInterval(24 * 3600))
                NSLog("=== \(events.count) events in next 24h ===")
                for event in events {
                    let link = MeetingLinks.extract(from: event)?.absoluteString ?? "-"
                    NSLog("[\(event.calendarTitle)] \(event.start) \(event.title) allDay=\(event.isAllDay) declined=\(event.isDeclined) link=\(link)")
                }
            } catch {
                NSLog("Calendar access failed: \(error)")
            }
        }
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
