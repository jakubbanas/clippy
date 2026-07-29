import Foundation

/// Best-effort extraction of a video-call URL from event fields.
enum MeetingLinks {
    private static let patterns = [
        #"https://[a-zA-Z0-9.-]*zoom\.us/j/[^\s<>"']+"#,
        #"https://meet\.google\.com/[a-z0-9-]+"#,
        #"https://teams\.microsoft\.com/l/meetup-join/[^\s<>"']+"#,
    ]

    static func extract(from event: EventInfo) -> URL? {
        if let url = event.url, firstLink(in: url.absoluteString) != nil {
            return url
        }
        for text in [event.location, event.notes].compactMap({ $0 }) {
            if let link = firstLink(in: normalizeHTML(text)) {
                return link
            }
        }
        return nil
    }

    static func firstLink(in text: String) -> URL? {
        for pattern in patterns {
            if let range = text.range(of: pattern, options: .regularExpression) {
                return URL(string: String(text[range]))
            }
        }
        return nil
    }

    /// Google-synced events embed links inside HTML notes, often as href
    /// attributes — so tags must NOT be stripped (that would delete the URL).
    /// The link patterns already stop at <>"' boundaries; only entities need
    /// decoding so URLs containing &amp; come out clean.
    static func normalizeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }
}
