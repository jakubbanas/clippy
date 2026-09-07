import AppKit

/// Borderless one-field panel for adding a priority. A separate window rather
/// than a text field in the menu itself: a menu runs its own event-tracking
/// loop, so an `NSTextField` inside a menu item's view cannot reliably take
/// keyboard focus. Enter adds, Escape cancels; blank text just closes.
///
/// Modeled on `FocusStartWindow` (kept separate to keep the two panels simple).
final class PriorityInputWindow {
    private final class Panel: NSPanel {
        override var canBecomeKey: Bool { true }
    }

    private static let size = NSSize(width: 380, height: 100)

    private let panel: Panel
    private let textField = NSTextField()
    private var escMonitor: Any?

    /// The trimmed text of a committed priority.
    var onAdd: ((String) -> Void)?

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

        let content = NSView(frame: NSRect(origin: .zero, size: Self.size))
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        content.layer?.cornerRadius = 12
        panel.contentView = content

        let prompt = NSTextField(labelWithString: "What's a priority today?")
        prompt.font = .boldSystemFont(ofSize: 13)

        textField.placeholderString = "e.g. finish the priorities list"
        textField.font = .systemFont(ofSize: 13)
        textField.target = self
        textField.action = #selector(submit)

        let stack = NSStackView(views: [prompt, textField])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -18),
            stack.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            textField.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    func show() {
        textField.stringValue = ""
        positionTopCenter()

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(textField)

        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.close()
                return nil
            }
            return event
        }
    }

    func close() {
        if let escMonitor { NSEvent.removeMonitor(escMonitor); self.escMonitor = nil }
        panel.orderOut(nil)
    }

    @objc private func submit() {
        let text = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        close()
        guard !text.isEmpty else { return }
        onAdd?(text)
    }

    private func positionTopCenter() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let origin = NSPoint(
            x: visible.midX - Self.size.width / 2,
            y: visible.maxY - Self.size.height - 120
        )
        panel.setFrame(NSRect(origin: origin, size: Self.size), display: true)
    }
}
