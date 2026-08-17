import AppKit

/// The Raycast-style search window: a text field over a sectioned result list.
///
/// Deliberately not `ClippyWindow`. That panel is non-activating so Clippy never
/// steals focus; a search field needs the exact opposite. Plain system chrome,
/// no sprite and no speech bubble — this is a tool that is on screen for under
/// two seconds, not an announcement.
final class LauncherWindow: NSObject, NSTableViewDelegate, NSTableViewDataSource, NSTextFieldDelegate {
    private final class Panel: NSPanel {
        override var canBecomeKey: Bool { true }
    }

    /// One rendered line: either a section header or a pickable command.
    private enum Row {
        case header(String)
        case command(Command)
    }

    private static let width: CGFloat = 560
    private static let fieldHeight: CGFloat = 56
    private static let rowHeight: CGFloat = 36
    private static let headerHeight: CGFloat = 28
    private static let maxListHeight: CGFloat = 340
    /// Breathing room above the first row and below the last. Counted in
    /// `resize()` too, or the last row gets clipped.
    private static let listPadding: CGFloat = 8

    private let panel: Panel
    private let field = NSTextField()
    private let table = NSTableView()
    private let scrollView = NSScrollView()
    private var rows: [Row] = []
    private var keyMonitor: Any?
    /// Whoever was frontmost when we opened, so ⌘V after a pick lands there.
    private var previousApp: NSRunningApplication?

    /// Asks the owner to rank a query into sections. The window never knows
    /// where rows come from.
    var onQueryChanged: ((String) -> [LauncherSection])?
    var onPick: ((Command) -> Void)?

    override init() {
        // [.borderless] only — exactly what FocusStartWindow uses. Do NOT add
        // .nonactivatingPanel: that is ClippyWindow's flag, and it fights the
        // keyboard focus a search field needs.
        panel = Panel(
            contentRect: NSRect(x: 0, y: 0, width: Self.width, height: Self.fieldHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.hasShadow = true
        panel.backgroundColor = .clear

        let content = NSView()
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        content.layer?.cornerRadius = 12
        content.layer?.masksToBounds = true
        panel.contentView = content

        field.placeholderString = "Search apps, commands, clipboard…"
        field.font = .systemFont(ofSize: 20)
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.delegate = self
        field.translatesAutoresizingMaskIntoConstraints = false

        table.headerView = nil
        table.rowHeight = Self.rowHeight
        // Default is 2pt per row, which `resize()` would not account for — three
        // rows of slack is enough to clip the last one.
        table.intercellSpacing = .zero
        table.backgroundColor = .clear
        table.selectionHighlightStyle = .regular
        table.delegate = self
        table.dataSource = self
        table.target = self
        table.action = #selector(rowClicked)
        table.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("main")))

        scrollView.documentView = table
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(field)
        content.addSubview(separator)
        content.addSubview(scrollView)
        NSLayoutConstraint.activate([
            // Centered in a fieldHeight-tall band rather than pinned to the top
            // with a fixed height, which draws the text high in its own box.
            field.centerYAnchor.constraint(
                equalTo: content.topAnchor, constant: Self.fieldHeight / 2
            ),
            field.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            field.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            separator.topAnchor.constraint(equalTo: content.topAnchor, constant: Self.fieldHeight),
            separator.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: Self.listPadding),
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -Self.listPadding),
        ])
    }

    // MARK: - Lifecycle

    func show() {
        // The hotkey fires system-wide, including while this window is already
        // up — Raycast muscle memory is to press it again. Without this toggle,
        // the second press re-captures Clippy itself as `previousApp`, which is
        // sticky: from then on every close reactivates Clippy, so a picked clip's
        // ⌘V lands nowhere for the rest of the session. It also leaked one
        // NSEvent monitor per extra press.
        if panel.isVisible {
            close()
            return
        }
        // Captured BEFORE activating, or it is already us. Belt and braces
        // against the sticky failure above: never store ourselves.
        let front = NSWorkspace.shared.frontmostApplication
        previousApp = front?.bundleIdentifier == Bundle.main.bundleIdentifier ? nil : front
        field.stringValue = ""
        // position() BEFORE refresh(): position sets the frame to field height
        // only, so calling it second would discard the height refresh() computed
        // and the empty-query rows would be invisible until the first keystroke.
        position()
        refresh()

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(field)

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event) ?? event
        }
    }

    func close() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor); self.keyMonitor = nil }
        panel.orderOut(nil)
        // Hand focus back so a following ⌘V lands where the user was typing.
        previousApp?.activate()
        previousApp = nil
    }

    // MARK: - Keyboard

    /// Returns nil to swallow the event, or the event to let it through.
    private func handle(_ event: NSEvent) -> NSEvent? {
        switch event.keyCode {
        case 53: // Escape
            close()
            return nil
        case 125: // Down
            move(by: 1)
            return nil
        case 126: // Up
            move(by: -1)
            return nil
        case 36, 76: // Return, keypad Enter
            pickSelected()
            return nil
        default:
            return event
        }
    }

    private func move(by delta: Int) {
        let pickable = rows.indices.filter { if case .command = rows[$0] { return true } else { return false } }
        guard !pickable.isEmpty else { return }
        let current = table.selectedRow
        let position = pickable.firstIndex(of: current) ?? -1
        let next = max(0, min(pickable.count - 1, position + delta))
        table.selectRowIndexes([pickable[next]], byExtendingSelection: false)
        table.scrollRowToVisible(pickable[next])
    }

    private func pickSelected() {
        guard rows.indices.contains(table.selectedRow),
              case .command(let command) = rows[table.selectedRow] else { return }
        close()
        onPick?(command)
    }

    @objc private func rowClicked() {
        pickSelected()
    }

    func controlTextDidChange(_ obj: Notification) {
        refresh()
    }

    // MARK: - Rendering

    private func refresh() {
        let sections = onQueryChanged?(field.stringValue) ?? []
        rows = sections.flatMap { section -> [Row] in
            [.header(section.title)] + section.commands.map(Row.command)
        }
        table.reloadData()
        // Auto-select the first pickable row so Enter always does the obvious thing.
        if let first = rows.firstIndex(where: { if case .command = $0 { return true } else { return false } }) {
            table.selectRowIndexes([first], byExtendingSelection: false)
        }
        resize()
    }

    private func resize() {
        var listHeight: CGFloat = 0
        for row in rows {
            listHeight += { if case .header = row { return Self.headerHeight } else { return Self.rowHeight } }()
        }
        if rows.isEmpty && !field.stringValue.isEmpty { listHeight = Self.rowHeight } // "No results"
        listHeight = min(listHeight, Self.maxListHeight)
        // The list's own top/bottom insets; without them the last row is clipped.
        if listHeight > 0 { listHeight += Self.listPadding * 2 }

        let height = Self.fieldHeight + 1 + listHeight
        var frame = panel.frame
        frame.origin.y += frame.height - height // grow downward, keep the field put
        frame.size.height = height
        panel.setFrame(frame, display: true)
    }

    private func position() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        panel.setFrame(
            NSRect(
                x: visible.midX - Self.width / 2,
                y: visible.maxY - Self.fieldHeight - 140,
                width: Self.width,
                height: Self.fieldHeight
            ),
            display: true
        )
    }

    // MARK: - Table

    func numberOfRows(in tableView: NSTableView) -> Int {
        rows.isEmpty && !field.stringValue.isEmpty ? 1 : rows.count
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard rows.indices.contains(row) else { return Self.rowHeight }
        if case .header = rows[row] { return Self.headerHeight }
        return Self.rowHeight
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        guard rows.indices.contains(row) else { return false }
        if case .command = rows[row] { return true }
        return false
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard rows.indices.contains(row) else { return emptyRowView() }
        switch rows[row] {
        case .header(let title):
            let label = NSTextField(labelWithString: title.uppercased())
            label.font = .systemFont(ofSize: 10, weight: .semibold)
            label.textColor = .tertiaryLabelColor
            return padded(label)
        case .command(let command):
            return commandRowView(command)
        }
    }

    private func commandRowView(_ command: Command) -> NSView {
        let icon = NSImageView()
        icon.image = command.icon
        icon.imageScaling = .scaleProportionallyDown
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let title = NSTextField(labelWithString: command.title)
        title.font = .systemFont(ofSize: 14)
        title.lineBreakMode = .byTruncatingTail

        let subtitle = NSTextField(labelWithString: command.subtitle ?? "")
        subtitle.font = .systemFont(ofSize: 11)
        subtitle.textColor = .secondaryLabelColor
        subtitle.lineBreakMode = .byTruncatingMiddle
        subtitle.alignment = .right

        let stack = NSStackView(views: [icon, title, subtitle])
        stack.orientation = .horizontal
        stack.spacing = 10
        icon.widthAnchor.constraint(equalToConstant: 20).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 20).isActive = true
        title.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        return padded(stack)
    }

    private func emptyRowView() -> NSView {
        let label = NSTextField(labelWithString: "No results")
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabelColor
        return padded(label)
    }

    private func padded(_ view: NSView) -> NSView {
        let container = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            view.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        return container
    }
}
