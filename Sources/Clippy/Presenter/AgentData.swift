import AppKit

/// Parsed clippy.js agent data: sprite sheet geometry + named animations.
struct AgentData: Decodable {
    let framesize: [Double]
    let animations: [String: Animation]

    struct Animation: Decodable {
        let frames: [Frame]
        let useExitBranching: Bool?

        enum CodingKeys: String, CodingKey {
            case frames, useExitBranching
        }
    }

    struct Frame: Decodable {
        /// Milliseconds.
        let duration: Double
        /// Layered [x, y] offsets into the sprite sheet; first layer is the base.
        /// Absent = blank frame (Clippy hidden).
        let images: [[Double]]?

        enum CodingKeys: String, CodingKey {
            case duration, images
        }
    }

    var frameWidth: CGFloat { CGFloat(framesize[0]) }
    var frameHeight: CGFloat { CGFloat(framesize[1]) }
}

enum ClippyAssets {
    static func load() throws -> (data: AgentData, sheet: CGImage) {
        guard let jsonURL = Bundle.module.url(forResource: "agent", withExtension: "json", subdirectory: "clippy"),
              let pngURL = Bundle.module.url(forResource: "map", withExtension: "png", subdirectory: "clippy")
        else {
            throw CocoaError(.fileNoSuchFile)
        }
        let data = try JSONDecoder().decode(AgentData.self, from: Data(contentsOf: jsonURL))
        guard let image = NSImage(contentsOf: pngURL),
              let sheet = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return (data, sheet)
    }
}
