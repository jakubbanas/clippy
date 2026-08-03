import AppKit

/// Borderless transparent panel showing Clippy at all times — a static resting pose
/// when idle, or the active announcement's bubble + animation. Draggable while idle;
/// dragging is disabled during an announcement so it can't fight the bubble layout.
final class ClippyWindow {
    private static let size = NSSize(width: 380, height: 340)
    private static let margin: CGFloat = 16
    private static let idleAnimations = [
        "IdleRopePile", "IdleAtom", "Idle1_1", "IdleSideToSide",
        "IdleHeadScratch", "IdleSnooze", "IdleFingerTap", "IdleEyeBrowRaise",
    ]

    private let panel: NSPanel
    private let sprite: SpriteView
    private let bubble = BubbleView()
    private let statusContainer = NSView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let dragView = DragClickView()
    private var isAnnouncing = false

    var onAction: ((AnnouncementAction.Kind) -> Void)?

    init(agent: AgentData, sheet: CGImage) {
        sprite = SpriteView(agent: agent, sheet: sheet)

        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false

        dragView.frame = NSRect(origin: .zero, size: Self.size)
        panel.contentView = dragView

        sprite.translatesAutoresizingMaskIntoConstraints = false
        bubble.translatesAutoresizingMaskIntoConstraints = false

        statusContainer.wantsLayer = true
        statusContainer.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.55).cgColor
        statusContainer.layer?.cornerRadius = 8
        statusContainer.isHidden = true
        statusContainer.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = .boldSystemFont(ofSize: 12)
        statusLabel.textColor = .white
        statusLabel.maximumNumberOfLines = 1
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        dragView.addSubview(bubble)
        dragView.addSubview(statusContainer)
        statusContainer.addSubview(statusLabel)
        dragView.addSubview(sprite)
        NSLayoutConstraint.activate([
            sprite.trailingAnchor.constraint(equalTo: dragView.trailingAnchor, constant: -8),
            sprite.bottomAnchor.constraint(equalTo: statusContainer.topAnchor, constant: -6),
            sprite.widthAnchor.constraint(equalToConstant: sprite.intrinsicContentSize.width),
            sprite.heightAnchor.constraint(equalToConstant: sprite.intrinsicContentSize.height),
            bubble.leadingAnchor.constraint(greaterThanOrEqualTo: dragView.leadingAnchor, constant: 8),
            bubble.trailingAnchor.constraint(equalTo: dragView.trailingAnchor, constant: -8),
            bubble.bottomAnchor.constraint(equalTo: sprite.topAnchor, constant: -10),
            statusContainer.trailingAnchor.constraint(equalTo: dragView.trailingAnchor, constant: -8),
            statusContainer.leadingAnchor.constraint(greaterThanOrEqualTo: dragView.leadingAnchor, constant: 8),
            statusContainer.bottomAnchor.constraint(equalTo: dragView.bottomAnchor, constant: -8),
            statusLabel.leadingAnchor.constraint(equalTo: statusContainer.leadingAnchor, constant: 8),
            statusLabel.trailingAnchor.constraint(equalTo: statusContainer.trailingAnchor, constant: -8),
            statusLabel.topAnchor.constraint(equalTo: statusContainer.topAnchor, constant: 4),
            statusLabel.bottomAnchor.constraint(equalTo: statusContainer.bottomAnchor, constant: -4),
        ])

        bubble.onAction = { [weak self] kind in self?.onAction?(kind) }
        dragView.onClick = { [weak self] in self?.handleClick() }
        dragView.onDragged = { [weak self] proposedOrigin in
            guard let self else { return }
            self.panel.setFrameOrigin(self.clampedOrigin(proposedOrigin))
        }

        positionBottomRight()
        enterIdle()
        panel.orderFrontRegardless()
    }

    /// Configures the bubble and plays the announcement's animation. The window is
    /// already on screen wherever Clippy currently sits — this does not reposition it.
    func show(_ announcement: Announcement) {
        isAnnouncing = true
        dragView.isDraggable = false
        bubble.isHidden = false
        bubble.configure(with: announcement)
        sprite.play(announcement.animation)
    }

    /// Returns to the idle resting pose — Clippy stays on screen, so no exit animation.
    func dismiss(completion: @escaping () -> Void) {
        enterIdle()
        completion()
    }

    /// Shows/hides the persistent focus-session status, independent of the
    /// announcement queue and of idle/announcing state. Nil or empty hides it.
    func setStatus(_ text: String?) {
        if let text, !text.isEmpty {
            statusLabel.stringValue = text
            statusContainer.isHidden = false
        } else {
            statusContainer.isHidden = true
        }
    }

    /// Orders the window off screen, independent of idle/announcement state.
    func hideManually() {
        panel.orderOut(nil)
    }

    /// Restores the window on screen, showing whatever state (idle or announcement)
    /// it was already in.
    func showManually() {
        panel.orderFrontRegardless()
    }

    private func enterIdle() {
        isAnnouncing = false
        dragView.isDraggable = true
        bubble.isHidden = true
        sprite.play("RestPose")
    }

    private func handleClick() {
        if isAnnouncing {
            onAction?(.dismiss)
            return
        }
        let name = Self.pickIdleAnimation(
            from: Self.idleAnimations,
            index: Int.random(in: 0..<Self.idleAnimations.count)
        )
        sprite.play(name) { [weak self] in
            self?.sprite.play("RestPose")
        }
    }

    private func positionBottomRight() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let origin = NSPoint(
            x: visible.maxX - Self.size.width - Self.margin,
            y: visible.minY + Self.margin
        )
        panel.setFrame(NSRect(origin: origin, size: Self.size), display: true)
    }

    private func clampedOrigin(_ proposed: NSPoint) -> NSPoint {
        guard let screen = panel.screen ?? NSScreen.main else { return proposed }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let x = min(max(proposed.x, visible.minX), visible.maxX - size.width)
        let y = min(max(proposed.y, visible.minY), visible.maxY - size.height)
        return NSPoint(x: x, y: y)
    }

    /// Distance-based click/drag classification, pulled out for unit testing.
    static func isDrag(from start: NSPoint, to end: NSPoint, threshold: CGFloat) -> Bool {
        let dx = end.x - start.x
        let dy = end.y - start.y
        return (dx * dx + dy * dy) > threshold * threshold
    }

    /// Picks an idle-reaction animation name from a fixed set by index (not live
    /// randomness), so animation selection is unit-testable.
    static func pickIdleAnimation(from set: [String], index: Int) -> String {
        set[index % set.count]
    }
}

/// Content view that distinguishes a click from a drag by total mouse movement, and
/// reports drags as a proposed new window origin for the owner to clamp and apply.
/// The whole view's bounding box captures mouse events (no per-pixel hit-testing).
final class DragClickView: NSView {
    private static let clickThreshold: CGFloat = 4

    var onClick: (() -> Void)?
    var onDragged: ((NSPoint) -> Void)?
    var isDraggable = true

    private var dragStartScreenPoint: NSPoint?
    private var dragStartWindowOrigin: NSPoint?
    private var didDrag = false

    override func mouseDown(with event: NSEvent) {
        dragStartScreenPoint = NSEvent.mouseLocation
        dragStartWindowOrigin = window?.frame.origin
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDraggable,
              let startScreen = dragStartScreenPoint,
              let startOrigin = dragStartWindowOrigin else { return }
        let current = NSEvent.mouseLocation
        if ClippyWindow.isDrag(from: startScreen, to: current, threshold: Self.clickThreshold) {
            didDrag = true
        }
        guard didDrag else { return }
        let delta = NSPoint(x: current.x - startScreen.x, y: current.y - startScreen.y)
        onDragged?(NSPoint(x: startOrigin.x + delta.x, y: startOrigin.y + delta.y))
    }

    override func mouseUp(with event: NSEvent) {
        if !didDrag {
            onClick?()
        }
        dragStartScreenPoint = nil
        dragStartWindowOrigin = nil
    }
}
