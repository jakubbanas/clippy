import AppKit

/// Thin horizontal progress bar: a translucent track with a green filled
/// portion representing `progress` (0...1), left-anchored, resizing with
/// the view. No animation — the fill snaps to the new value.
final class ProgressBarView: NSView {
    private let fillLayer = CALayer()

    /// 0...1. Values outside that range are clamped when the fill is drawn.
    var progress: Double = 0 {
        didSet { updateFillFrame() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.25).cgColor
        layer?.cornerRadius = 2
        fillLayer.backgroundColor = NSColor.systemGreen.cgColor
        fillLayer.cornerRadius = 2
        layer?.addSublayer(fillLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("ProgressBarView does not support NSCoder")
    }

    override func layout() {
        super.layout()
        updateFillFrame()
    }

    private func updateFillFrame() {
        let clamped = max(0, min(1, progress))
        fillLayer.frame = CGRect(x: 0, y: 0, width: bounds.width * clamped, height: bounds.height)
    }
}
