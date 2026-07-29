import AppKit

/// Plays named sprite-sheet animations from clippy.js agent data.
/// Main thread only. Playback is linear (branching/looping data is ignored);
/// a safety cap bounds animations that were authored to loop.
final class SpriteView: NSView {
    private let agent: AgentData
    private let sheet: CGImage
    private let spriteLayer = CALayer()
    private var pendingStep: DispatchWorkItem?
    private var frameCache: [String: [CGImage?]] = [:]

    /// Called when the user clicks the sprite itself (as opposed to a bubble button).
    var onClick: (() -> Void)?

    private static let maxFramesPerPlay = 120
    /// Multiplier on each frame's authored duration; <1 plays faster.
    private static let speedMultiplier = 0.5

    init(agent: AgentData, sheet: CGImage) {
        self.agent = agent
        self.sheet = sheet
        super.init(frame: NSRect(x: 0, y: 0, width: agent.frameWidth, height: agent.frameHeight))
        wantsLayer = true
        spriteLayer.magnificationFilter = .nearest
        spriteLayer.frame = bounds
        spriteLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        layer?.addSublayer(spriteLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        NSSize(width: agent.frameWidth, height: agent.frameHeight)
    }

    /// Plays the animation to completion, then calls `completion`.
    /// Unknown animation names complete immediately.
    func play(_ name: String, completion: (() -> Void)? = nil) {
        stop()
        guard let animation = agent.animations[name] else {
            completion?()
            return
        }
        let frames = Array(animation.frames.prefix(Self.maxFramesPerPlay))
        step(name: name, frames: frames, index: 0, completion: completion)
    }

    func stop() {
        pendingStep?.cancel()
        pendingStep = nil
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    private func step(name: String, frames: [AgentData.Frame], index: Int, completion: (() -> Void)?) {
        guard index < frames.count else {
            completion?()
            return
        }
        show(frame: frames[index], of: name, at: index)
        let work = DispatchWorkItem { [weak self] in
            self?.step(name: name, frames: frames, index: index + 1, completion: completion)
        }
        pendingStep = work
        let delay = frames[index].duration / 1000 * Self.speedMultiplier
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func show(frame: AgentData.Frame, of name: String, at index: Int) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if let image = cachedFrame(of: name, at: index, frame: frame) {
            spriteLayer.contents = image
            spriteLayer.isHidden = false
        } else {
            spriteLayer.isHidden = true
        }
        CATransaction.commit()
    }

    private func cachedFrame(of name: String, at index: Int, frame: AgentData.Frame) -> CGImage? {
        if frameCache[name] == nil {
            frameCache[name] = Array(repeating: nil, count: Self.maxFramesPerPlay)
        }
        if let cached = frameCache[name]?[index] {
            return cached
        }
        guard let offset = frame.images?.first, offset.count >= 2 else { return nil }
        let rect = CGRect(x: offset[0], y: offset[1], width: agent.frameWidth, height: agent.frameHeight)
        let cropped = sheet.cropping(to: rect)
        frameCache[name]?[index] = cropped
        return cropped
    }
}
