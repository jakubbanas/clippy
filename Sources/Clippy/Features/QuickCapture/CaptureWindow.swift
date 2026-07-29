import AppKit

/// Borderless input panel for capturing a reminder: a text field + a short time
/// field. Owned by the feature (not the `Presenter`) — capture is *input*, with
/// its own lifecycle, distinct from the announcement *output* the presenter runs.
///
/// Enter submits, Escape cancels. `onSubmit` returns false when the time string
/// can't be parsed; the panel then stays open and shows an error instead of
/// saving a broken reminder.
final class CaptureWindow {
    /// A borderless panel must opt in to key status to host text editing.
    private final class Panel: NSPanel {
        override var canBecomeKey: Bool { true }
    }

    private static let size = NSSize(width: 380, height: 150)

    private let panel: Panel
    private let textField = NSTextField()
    private let timeField = NSTextField()
    private let errorLabel = NSTextField(labelWithString: "")
    private var escMonitor: Any?

    /// (reminder text, time string) → was it accepted? False keeps the panel open.
    var onSubmit: ((String, String) -> Bool)?

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

        let prompt = NSTextField(labelWithString: "What should I remind you about?")
        prompt.font = .boldSystemFont(ofSize: 13)

        textField.placeholderString = "e.g. Call the dentist"
        timeField.placeholderString = "When? e.g. 20m, 2h, 3pm, 9:30am"
        for field in [textField, timeField] {
            field.target = self
            field.action = #selector(submit)
            field.font = .systemFont(ofSize: 13)
        }
        textField.nextKeyView = timeField

        errorLabel.textColor = .systemRed
        errorLabel.font = .systemFont(ofSize: 11)
        errorLabel.isHidden = true

        let stack = NSStackView(views: [prompt, textField, timeField, errorLabel])
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
            timeField.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    func show() {
        textField.stringValue = ""
        timeField.stringValue = ""
        errorLabel.isHidden = true
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
        let accepted = onSubmit?(textField.stringValue, timeField.stringValue) ?? false
        if accepted {
            close()
        } else {
            errorLabel.stringValue = "I need reminder text and a time I understand (e.g. 20m or 3pm)."
            errorLabel.isHidden = false
        }
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
