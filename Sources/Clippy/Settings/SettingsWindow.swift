import AppKit
import SwiftUI

/// Plain titled window hosting `SettingsView`. Follows the system appearance,
/// unlike the always-dark popover.
final class SettingsWindow: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private var hasBeenShown = false
    /// Called when the user closes the window; the owner decides whether to reload.
    var onClose: (() -> Void)?

    init(model: SettingsModel) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 460),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init()
        window.title = "Clippy Settings"
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: SettingsView(model: model))
        window.setContentSize(NSSize(width: 640, height: 460))
        window.delegate = self
    }

    func show() {
        if !hasBeenShown {
            window.center()
            hasBeenShown = true
        }
        // An accessory app is never active on its own; without this the
        // window opens behind whatever app is frontmost.
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}
