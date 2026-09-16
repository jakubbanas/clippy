import Foundation

/// Filters clipboard history for the history window. Pure and static, in the
/// shape of `ClipboardStore`'s value transforms.
///
/// Substring matching, deliberately not `FuzzyMatch`: a query is a *subsequence*
/// of a 200-character clip essentially always, so fuzzy matching over clip text
/// filters nothing and leaves ordering to noise. Clips are also never scored —
/// history order (newest first) is the order you want, so matches come back in
/// the order they went in.
enum ClipboardSearch {
    /// Every whitespace-separated term must appear somewhere in the clip, in any
    /// order, ignoring case and diacritics. An empty or blank query matches all.
    static func filter(_ clips: [Clip], query: String) -> [Clip] {
        let terms = query.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        guard !terms.isEmpty else { return clips }
        return clips.filter { clip in
            terms.allSatisfy { term in
                clip.text.range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }
    }
}
