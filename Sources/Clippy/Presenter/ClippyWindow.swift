import AppKit

/// Borderless transparent panel in the bottom-right screen corner.
/// Exists on screen only while an announcement is showing.
final class ClippyWindow {
    private static let size = NSSize(width: 380, height: 340)
    private static let margin: CGFloat = 16

    private let panel: NSPanel
    private let sprite: SpriteView
    private let bubble = BubbleView()

    var onAction: ((AnnouncementAction.Kind) -> Void)? {
        get { bubble.onAction }
        set { bubble.onAction = newValue }
    }

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

        let content = NSView(frame: NSRect(origin: .zero, size: Self.size))
        panel.contentView = content

        sprite.translatesAutoresizingMaskIntoConstraints = false
        bubble.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(bubble)
        content.addSubview(sprite)
        NSLayoutConstraint.activate([
            sprite.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -8),
            sprite.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -8),
            sprite.widthAnchor.constraint(equalToConstant: sprite.intrinsicContentSize.width),
            sprite.heightAnchor.constraint(equalToConstant: sprite.intrinsicContentSize.height),
            bubble.leadingAnchor.constraint(greaterThanOrEqualTo: content.leadingAnchor, constant: 8),
            bubble.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -8),
            bubble.bottomAnchor.constraint(equalTo: sprite.topAnchor, constant: -10),
        ])
    }

    /// Slides in, plays the announcement's animation, leaves the bubble up.
    func show(_ announcement: Announcement) {
        bubble.configure(with: announcement)
        positionBottomRight()

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            panel.animator().alphaValue = 1
        }
        sprite.play(announcement.animation)
    }

    /// Plays the goodbye animation (if present), then hides.
    func dismiss(completion: @escaping () -> Void) {
        sprite.play("GoodBye") { [panel] in
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                panel.animator().alphaValue = 0
            }, completionHandler: {
                panel.orderOut(nil)
                completion()
            })
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
}
