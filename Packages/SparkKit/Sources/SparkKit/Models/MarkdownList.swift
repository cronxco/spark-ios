import Foundation

/// The bullet markers Flint and the newsletter summarisers actually write.
///
/// The dashes are the point. The briefing style guide writes its cheat sheets as
/// `— ` lines, so a renderer that only knew `-`, `*` and `•` ran a six-item list
/// together into one paragraph — which is how an entire evening digest came to be
/// a single unsplittable block of text.
public enum MarkdownList {
    /// Longest-lived first; every marker is one character plus a space, but the
    /// prefix is stripped by its own length rather than by assuming that.
    public static let bulletMarkers = ["- ", "* ", "• ", "— ", "– "]

    public static func isBullet(_ line: String) -> Bool {
        bulletMarkers.contains { line.hasPrefix($0) }
    }

    public static func stripBullet(_ line: String) -> String {
        guard let marker = bulletMarkers.first(where: { line.hasPrefix($0) }) else {
            return line
        }
        return String(line.dropFirst(marker.count))
    }
}
