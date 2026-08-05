import AppKit

/// Borderless popup showing `ActivityStatsView`'s two charts. Read-only: no
/// input, closes on Escape or a click outside. Modeled on `FocusStartWindow`
/// (borderless `NSPanel` + a `canBecomeKey` subclass), but additionally
/// closes on an outside click since there's nothing here to submit.
final class ActivityStatsWindow {
    private final class Panel: NSPanel {
        override var canBecomeKey: Bool { true }
    }

    private static let size = NSSize(width: 420, height: 300)

    private let panel: Panel
    private let chartView = ActivityStatsView(frame: NSRect(origin: .zero, size: ActivityStatsWindow.size))
    private var escMonitor: Any?
    private var clickMonitor: Any?

    init() {
        panel = Panel(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.hasShadow = true
        panel.contentView = chartView
    }

    func show(week: [DayStat], day: [HourStat]) {
        chartView.configure(week: week, day: day)
        positionNearStatusItem()

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.close()
                return nil
            }
            return event
        }
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }
    }

    func close() {
        if let escMonitor { NSEvent.removeMonitor(escMonitor); self.escMonitor = nil }
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor); self.clickMonitor = nil }
        panel.orderOut(nil)
    }

    private func positionNearStatusItem() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let origin = NSPoint(x: visible.maxX - Self.size.width - 12, y: visible.maxY - Self.size.height - 12)
        panel.setFrame(NSRect(origin: origin, size: Self.size), display: true)
    }
}
