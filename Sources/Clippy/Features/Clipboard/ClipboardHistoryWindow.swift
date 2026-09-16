import AppKit

/// The dedicated clipboard history window: search field over a list, with a
/// preview pane for the selected clip.
///
/// Built like `LauncherWindow` (key-accepting borderless panel, local keyDown
/// monitor, previous-app restore) rather than `ClippyWindow`, because a search
/// field needs keyboard focus. Separate from `LauncherWindow` because a clip
/// list is not a `Command` list: rows need a preview pane and a delete key, and
/// clips are filtered by substring and ordered by recency, never scored.
///
/// Owns no state beyond the current filter — `ClipboardFeature` holds the clips
/// and this asks for them through closures, so the window never touches disk.
final class ClipboardHistoryWindow: NSObject, NSTableViewDelegate, NSTableViewDataSource, NSTextFieldDelegate {
    private final class Panel: NSPanel {
        override var canBecomeKey: Bool { true }
    }

    private static let width: CGFloat = 720
    private static let height: CGFloat = 420
    private static let fieldHeight: CGFloat = 48
    private static let listWidth: CGFloat = 280
    private static let rowHeight: CGFloat = 32
    private static let footerBarHeight: CGFloat = 30
    /// The list and preview have no intrinsic height, so without a floor here
    /// the top-to-bottom constraint chain resolves the body to zero and NSWindow
    /// shrinks the panel to field + footer. `position()`'s taller frame then
    /// satisfies this as an inequality.
    private static let minBodyHeight: CGFloat = 200

    private let panel: Panel
    private let field = NSTextField()
    private let table = NSTableView()
    private let preview = NSTextView()
    private let footer = NSTextField(labelWithString: "")
    private var clips: [Clip] = []
    private var keyMonitor: Any?
    /// Whoever was frontmost when we opened, so ⌘V after a pick lands there.
    private var previousApp: NSRunningApplication?

    /// The full history, newest first. Called on open and after every delete.
    var onLoad: (() -> [Clip])?
    var onPick: ((Clip) -> Void)?
    var onDelete: ((Clip) -> Void)?

    override init() {
        panel = Panel(
            contentRect: NSRect(x: 0, y: 0, width: Self.width, height: Self.height),
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

        field.placeholderString = "Search clipboard history…"
        field.font = .systemFont(ofSize: 18)
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.delegate = self
        field.translatesAutoresizingMaskIntoConstraints = false

        table.headerView = nil
        table.rowHeight = Self.rowHeight
        table.intercellSpacing = .zero
        table.backgroundColor = .clear
        table.selectionHighlightStyle = .regular
        table.delegate = self
        table.dataSource = self
        table.target = self
        // Double-click, not click: a single click has to be free to move the
        // selection so the preview pane can follow it.
        table.doubleAction = #selector(rowDoubleClicked)
        table.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("clip")))

        let listScroll = NSScrollView()
        listScroll.documentView = table
        listScroll.hasVerticalScroller = true
        listScroll.drawsBackground = false
        listScroll.translatesAutoresizingMaskIntoConstraints = false

        // Monospaced: clip text here is overwhelmingly commands, SQL, URLs and
        // keys, and alignment is what makes those readable.
        preview.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        preview.isEditable = false
        preview.drawsBackground = false
        preview.textContainerInset = NSSize(width: 12, height: 12)
        // A hand-built NSTextView/NSScrollView pair does not wrap or scroll
        // without these: the text container has to track the view's width and be
        // free to grow downwards, or long clips render as one clipped line.
        preview.frame = NSRect(x: 0, y: 0, width: Self.width - Self.listWidth, height: Self.height)
        preview.minSize = .zero
        preview.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude
        )
        preview.isVerticallyResizable = true
        preview.isHorizontallyResizable = false
        preview.autoresizingMask = [.width]
        preview.textContainer?.widthTracksTextView = true
        preview.textContainer?.containerSize = NSSize(
            width: 0, height: CGFloat.greatestFiniteMagnitude
        )
        let previewScroll = NSScrollView()
        previewScroll.documentView = preview
        previewScroll.hasVerticalScroller = true
        previewScroll.drawsBackground = false
        previewScroll.translatesAutoresizingMaskIntoConstraints = false

        footer.font = .systemFont(ofSize: 11)
        footer.textColor = .secondaryLabelColor
        footer.lineBreakMode = .byTruncatingTail
        footer.translatesAutoresizingMaskIntoConstraints = false

        let hint = NSTextField(labelWithString: "↵ copy   ⌘⌫ delete   esc close")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .tertiaryLabelColor
        hint.alignment = .right
        hint.translatesAutoresizingMaskIntoConstraints = false

        let topSeparator = NSBox()
        topSeparator.boxType = .separator
        topSeparator.translatesAutoresizingMaskIntoConstraints = false
        let columnSeparator = NSBox()
        columnSeparator.boxType = .separator
        columnSeparator.translatesAutoresizingMaskIntoConstraints = false
        let footerSeparator = NSBox()
        footerSeparator.boxType = .separator
        footerSeparator.translatesAutoresizingMaskIntoConstraints = false

        for view in [field, topSeparator, listScroll, columnSeparator, previewScroll, footerSeparator, footer, hint] {
            content.addSubview(view)
        }

        NSLayoutConstraint.activate([
            field.centerYAnchor.constraint(equalTo: content.topAnchor, constant: Self.fieldHeight / 2),
            field.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            field.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),

            topSeparator.topAnchor.constraint(equalTo: content.topAnchor, constant: Self.fieldHeight),
            topSeparator.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            topSeparator.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            listScroll.topAnchor.constraint(equalTo: topSeparator.bottomAnchor),
            listScroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            listScroll.widthAnchor.constraint(equalToConstant: Self.listWidth),
            listScroll.bottomAnchor.constraint(equalTo: footerSeparator.topAnchor),
            listScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: Self.minBodyHeight),

            columnSeparator.leadingAnchor.constraint(equalTo: listScroll.trailingAnchor),
            columnSeparator.topAnchor.constraint(equalTo: topSeparator.bottomAnchor),
            columnSeparator.bottomAnchor.constraint(equalTo: footerSeparator.topAnchor),

            previewScroll.leadingAnchor.constraint(equalTo: columnSeparator.trailingAnchor),
            previewScroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            previewScroll.topAnchor.constraint(equalTo: topSeparator.bottomAnchor),
            previewScroll.bottomAnchor.constraint(equalTo: footerSeparator.topAnchor),

            footerSeparator.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            footerSeparator.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            footerSeparator.bottomAnchor.constraint(
                equalTo: content.bottomAnchor, constant: -Self.footerBarHeight
            ),

            footer.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            footer.centerYAnchor.constraint(
                equalTo: footerSeparator.bottomAnchor, constant: Self.footerBarHeight / 2
            ),
            hint.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            hint.leadingAnchor.constraint(greaterThanOrEqualTo: footer.trailingAnchor, constant: 12),
            hint.centerYAnchor.constraint(equalTo: footer.centerYAnchor),
        ])
    }

    // MARK: - Lifecycle

    func show() {
        guard !panel.isVisible else {
            panel.makeKeyAndOrderFront(nil)
            return
        }
        // Captured BEFORE activating, or it is already us. Never store ourselves:
        // LauncherWindow learned that a self-capture makes every close reactivate
        // Clippy, so the user's ⌘V lands nowhere.
        let front = NSWorkspace.shared.frontmostApplication
        previousApp = front?.bundleIdentifier == Bundle.main.bundleIdentifier ? nil : front

        field.stringValue = ""
        position()
        reload(selecting: 0)

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
        previousApp?.activate()
        previousApp = nil
    }

    private func position() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        panel.setFrame(
            NSRect(
                x: visible.midX - Self.width / 2,
                y: visible.midY - Self.height / 2 + 60,
                width: Self.width,
                height: Self.height
            ),
            display: true
        )
    }

    // MARK: - Keyboard

    /// Returns nil to swallow the event, or the event to let it through.
    private func handle(_ event: NSEvent) -> NSEvent? {
        // ⌘⌫ rather than plain ⌫: the search field always holds focus, so a bare
        // delete has to stay a backspace.
        if event.keyCode == 51, event.modifierFlags.contains(.command) {
            deleteSelected()
            return nil
        }
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
        guard !clips.isEmpty else { return }
        let next = max(0, min(clips.count - 1, table.selectedRow + delta))
        table.selectRowIndexes([next], byExtendingSelection: false)
        table.scrollRowToVisible(next)
    }

    private func pickSelected() {
        guard clips.indices.contains(table.selectedRow) else { return }
        let clip = clips[table.selectedRow]
        close()
        onPick?(clip)
    }

    private func deleteSelected() {
        guard clips.indices.contains(table.selectedRow) else { return }
        let row = table.selectedRow
        onDelete?(clips[row])
        // Hold the cursor where it was so a run of deletes keeps working.
        reload(selecting: row)
    }

    @objc private func rowDoubleClicked() {
        pickSelected()
    }

    func controlTextDidChange(_ obj: Notification) {
        reload(selecting: 0)
    }

    // MARK: - Rendering

    /// Re-filters and re-renders, landing the selection on `row` — or on the
    /// last row if the list has shrunk past it.
    private func reload(selecting row: Int) {
        clips = ClipboardSearch.filter(onLoad?() ?? [], query: field.stringValue)
        table.reloadData()
        let target = min(max(row, 0), clips.count - 1)
        guard clips.indices.contains(target) else {
            table.deselectAll(nil)
            // reloadData alone fires no selection notification, so the empty
            // case has to render itself.
            renderPreview(nil)
            return
        }
        table.selectRowIndexes([target], byExtendingSelection: false)
        table.scrollRowToVisible(target)
        // Rendered here, not left to tableViewSelectionDidChange: reloadData
        // preserves the selected index, so selecting it again is a no-op that
        // fires no notification — and filtering down to a new row 0 would leave
        // the preview showing the previous clip.
        renderPreview(clips[target])
    }

    private func renderPreview(_ clip: Clip?) {
        guard let clip else {
            preview.string = ""
            footer.stringValue = field.stringValue.isEmpty ? "No clipboard history yet" : "No results"
            return
        }
        preview.string = clip.text
        preview.scrollRangeToVisible(NSRange(location: 0, length: 0))
        let characters = clip.text.count == 1 ? "1 character" : "\(clip.text.count) characters"
        footer.stringValue = [clip.app, ClipboardFeature.relativeAge(from: clip.copiedAt, now: Date()), characters]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        renderPreview(clips.indices.contains(table.selectedRow) ? clips[table.selectedRow] : nil)
    }

    // MARK: - Table

    func numberOfRows(in tableView: NSTableView) -> Int {
        clips.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard clips.indices.contains(row) else { return NSView() }
        let label = NSTextField(labelWithString: ClipboardFeature.rowTitle(for: clips[row].text, maxLength: 44))
        label.font = .systemFont(ofSize: 13)
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        return container
    }
}
