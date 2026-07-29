import AppKit

/// Borderless input panel for starting a focus session: a goal field + a duration
/// field. Modeled on `CaptureWindow` (kept separate to keep the two features
/// isolated). Enter starts, Escape cancels; an empty goal or non-positive duration
/// keeps the panel open with an error instead of starting a bad session.
final class FocusStartWindow {
    private final class Panel: NSPanel {
        override var canBecomeKey: Bool { true }
    }

    private static let size = NSSize(width: 380, height: 165)

    private let panel: Panel
    private let goalField = NSTextField()
    private let minutesField = NSTextField()
    private let errorLabel = NSTextField(labelWithString: "")
    private var escMonitor: Any?
    private let defaultMinutes: Double

    /// (goal, minutes) once the user commits a valid session.
    var onStart: ((String, Double) -> Void)?

    init(defaultMinutes: Double) {
        self.defaultMinutes = defaultMinutes

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

        let prompt = NSTextField(labelWithString: "What are you working on?")
        prompt.font = .boldSystemFont(ofSize: 13)

        goalField.placeholderString = "e.g. refactor the Presenter"
        goalField.font = .systemFont(ofSize: 13)
        goalField.target = self
        goalField.action = #selector(submit)

        let minutesLabel = NSTextField(labelWithString: "For how long? (minutes)")
        minutesLabel.font = .systemFont(ofSize: 12)

        minutesField.font = .systemFont(ofSize: 13)
        minutesField.target = self
        minutesField.action = #selector(submit)
        goalField.nextKeyView = minutesField

        errorLabel.textColor = .systemRed
        errorLabel.font = .systemFont(ofSize: 11)
        errorLabel.isHidden = true

        let stack = NSStackView(views: [prompt, goalField, minutesLabel, minutesField, errorLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -18),
            stack.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            goalField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            minutesField.widthAnchor.constraint(equalToConstant: 70),
        ])
    }

    func show() {
        goalField.stringValue = ""
        minutesField.stringValue = String(Int(defaultMinutes))
        errorLabel.isHidden = true
        positionTopCenter()

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(goalField)

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
        let goal = goalField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let minutes = Int(minutesField.stringValue.trimmingCharacters(in: .whitespaces))
        guard !goal.isEmpty, let minutes, minutes > 0 else {
            errorLabel.stringValue = "I need a goal and a positive number of minutes."
            errorLabel.isHidden = false
            return
        }
        close()
        onStart?(goal, Double(minutes))
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
