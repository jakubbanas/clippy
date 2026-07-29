import AppKit

/// Retro yellow speech bubble: title, body lines, action buttons.
final class BubbleView: NSView {
    var onAction: ((AnnouncementAction.Kind) -> Void)?

    private let stack = NSStackView()
    private var actionKinds: [AnnouncementAction.Kind] = []

    override init(frame: NSRect) {
        super.init(frame: frame)
        // The bubble is always painted a fixed light yellow (see draw(_:)),
        // so force light-appearance rendering regardless of system Dark Mode —
        // otherwise labelColor/button styling resolve to their dark variants
        // and become unreadable against this always-light background.
        appearance = NSAppearance(named: .aqua)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func configure(with announcement: Announcement) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        actionKinds = announcement.actions.map(\.kind)

        let title = NSTextField(labelWithString: announcement.title)
        title.font = .boldSystemFont(ofSize: 13)
        title.textColor = .black
        title.maximumNumberOfLines = 2
        stack.addArrangedSubview(title)

        for line in announcement.body {
            let label = NSTextField(labelWithString: line)
            label.font = .systemFont(ofSize: 12)
            label.textColor = .black
            stack.addArrangedSubview(label)
        }

        if !announcement.actions.isEmpty {
            let buttons = NSStackView()
            buttons.orientation = .horizontal
            buttons.spacing = 8
            for (index, action) in announcement.actions.enumerated() {
                let button = NSButton(title: action.label, target: self, action: #selector(buttonPressed(_:)))
                button.bezelStyle = .rounded
                button.controlSize = .small
                button.bezelColor = Self.bezelColor(for: action.kind)
                button.tag = index
                buttons.addArrangedSubview(button)
            }
            stack.addArrangedSubview(buttons)
        }
    }

    /// Tints each action button by kind so they're distinguishable at a glance.
    private static func bezelColor(for kind: AnnouncementAction.Kind) -> NSColor {
        switch kind {
        case .openURL: return .systemGreen
        case .snooze: return .systemYellow
        case .dismiss: return .systemRed
        case .callback: return .systemBlue
        }
    }

    @objc private func buttonPressed(_ sender: NSButton) {
        guard actionKinds.indices.contains(sender.tag) else { return }
        onAction?(actionKinds[sender.tag])
    }

    override func draw(_ dirtyRect: NSRect) {
        let bubble = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 10, yRadius: 10)
        NSColor(calibratedRed: 1.0, green: 1.0, blue: 0.8, alpha: 1.0).setFill()
        bubble.fill()
        NSColor.black.setStroke()
        bubble.lineWidth = 1.5
        bubble.stroke()
    }
}
