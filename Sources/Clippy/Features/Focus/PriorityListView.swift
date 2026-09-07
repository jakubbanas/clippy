import AppKit

/// Today's priorities, rendered as rows inside the status-bar menu (the same
/// embedding trick `ActivityStatsView` uses). Each row is `[○] text … [✕]`:
/// the circle toggles done, the text starts a focus session on that priority,
/// the ✕ deletes it.
///
/// Built from real `NSButton`s rather than `draw(_:)` + hit-testing, because a
/// menu item's custom view forwards mouse events to its subviews — three
/// separate targets per row is exactly what buttons are for. Pure display plus
/// callbacks: it never touches `PriorityStore` itself.
final class PriorityListView: NSView {
    /// Start a focus session on this priority.
    var onStart: ((Priority) -> Void)?
    var onToggle: ((Priority) -> Void)?
    var onRemove: ((Priority) -> Void)?

    static let width: CGFloat = 320
    private static let rowHeight: CGFloat = 24
    private static let verticalPadding: CGFloat = 10
    private static let horizontalPadding: CGFloat = 20

    private let rowStack = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        let header = NSTextField(labelWithAttributedString: NSAttributedString(
            string: "TODAY",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: NSColor.secondaryLabelColor,
                .kern: 0.6,
            ]
        ))

        rowStack.orientation = .vertical
        rowStack.alignment = .leading
        rowStack.spacing = 0

        let stack = NSStackView(views: [header, rowStack])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.horizontalPadding),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.horizontalPadding),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: Self.verticalPadding),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.verticalPadding),
            rowStack.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unused") }

    /// Rebuilds the rows and resizes the view, since the menu sizes a custom
    /// item from its view's frame. Call before the menu opens, not while it is
    /// tracking — an open menu will not re-lay-out around a taller view.
    func configure(priorities: [Priority]) {
        rowStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if priorities.isEmpty {
            rowStack.addArrangedSubview(emptyRow())
        } else {
            priorities.forEach { rowStack.addArrangedSubview(row(for: $0)) }
        }
        // Height comes from the laid-out content, not arithmetic over the row
        // count — the header's real height and the stack spacing are Auto
        // Layout's to know, and guessing them clips the last row.
        layoutSubtreeIfNeeded()
        setFrameSize(NSSize(width: Self.width, height: fittingSize.height))
    }

    private func emptyRow() -> NSView {
        let label = NSTextField(labelWithString: "Nothing yet — add one below.")
        label.font = .systemFont(ofSize: 12)
        label.textColor = .tertiaryLabelColor
        return label
    }

    private func row(for priority: Priority) -> NSView {
        let toggle = ClosureButton(symbol: priority.done ? "checkmark.circle.fill" : "circle") { [weak self] in
            self?.onToggle?(priority)
        }
        toggle.contentTintColor = priority.done ? .controlAccentColor : .tertiaryLabelColor
        toggle.toolTip = priority.done ? "Mark as not done" : "Mark as done"

        let title = ClosureButton(title: priority.text, done: priority.done) { [weak self] in
            self?.onStart?(priority)
        }
        title.toolTip = "Start a focus session on this"

        let remove = ClosureButton(symbol: "xmark") { [weak self] in
            self?.onRemove?(priority)
        }
        remove.contentTintColor = .tertiaryLabelColor
        remove.toolTip = "Delete this priority"

        let row = NSStackView(views: [toggle, title, remove])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 6
        row.setHuggingPriority(.defaultLow, for: .horizontal)
        // The title takes the slack so the ✕ stays pinned to the right edge.
        title.setContentHuggingPriority(.defaultLow, for: .horizontal)
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: Self.rowHeight),
            toggle.widthAnchor.constraint(equalToConstant: 16),
            remove.widthAnchor.constraint(equalToConstant: 12),
        ])
        return row
    }
}

/// A borderless `NSButton` that runs a closure, so a row can carry three
/// independent actions without a target/selector dance per priority id.
private final class ClosureButton: NSButton {
    /// Not named `action` — `NSButton.action` is the inherited `Selector`.
    private let handler: () -> Void

    init(symbol: String, action: @escaping () -> Void) {
        self.handler = action
        super.init(frame: .zero)
        image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 11, weight: .regular))
        imagePosition = .imageOnly
        commonSetUp()
    }

    /// A done priority reads as struck-through secondary text but stays
    /// clickable — finishing something does not stop you re-running it.
    init(title: String, done: Bool, action: @escaping () -> Void) {
        self.handler = action
        super.init(frame: .zero)
        var attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: done ? NSColor.tertiaryLabelColor : NSColor.labelColor,
        ]
        if done { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        attributedTitle = NSAttributedString(string: title, attributes: attributes)
        alignment = .left
        lineBreakMode = .byTruncatingTail
        commonSetUp()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unused") }

    private func commonSetUp() {
        isBordered = false
        bezelStyle = .inline
        target = self
        action = #selector(fire)
    }

    @objc private func fire() {
        handler()
    }
}
