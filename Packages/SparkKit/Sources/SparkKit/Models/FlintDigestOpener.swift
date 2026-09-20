import Foundation

public extension FlintDigest {
    /// The digest's opening claim, for the Day tab's lede card.
    ///
    /// A digest summary opens with a greeting, then a section heading in
    /// capitals, then the paragraph that actually says something:
    ///
    /// ```
    /// Good Sunday morning.
    ///
    /// DRIVING THE DAY
    ///
    /// Today's genuinely quiet — nothing on your calendar…
    /// ```
    ///
    /// The Day tab shows the third part. The greeting is pleasant and says
    /// nothing, and a heading in capitals is not something the design system
    /// will set anywhere in the interface.
    var opener: String? { Self.opener(from: summary) }

    /// Exposed for the same reason it is tested: the shapes vary by run
    /// (an evening digest leads with a dashed cheat-sheet list) and this is
    /// the only place that knows about them.
    static func opener(from summary: String?, limit: Int = 260) -> String? {
        guard let summary else { return nil }

        let paragraphs = summary
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let first = paragraphs.first(where: { !isGreeting($0) && !isHeading($0) }) else {
            return nil
        }

        return truncate(clean(first), limit: limit)
    }

    /// "Good Sunday morning.", "Good evening" — a whole paragraph of it.
    private static func isGreeting(_ paragraph: String) -> Bool {
        let lower = paragraph.lowercased()
        guard lower.hasPrefix("good ") else { return false }
        // Only when the greeting is the entire paragraph; a digest that opens
        // "Good news on the mortgage…" is not a greeting.
        return paragraph.count <= 40 && !paragraph.contains("\n")
    }

    /// A section heading: set in capitals, sometimes trailed by a dash.
    private static func isHeading(_ paragraph: String) -> Bool {
        guard !paragraph.contains("\n") else { return false }
        let letters = paragraph.filter { $0.isLetter }
        guard !letters.isEmpty else { return false }
        return letters.allSatisfy { $0.isUppercase }
    }

    private static func clean(_ paragraph: String) -> String {
        var text = paragraph

        // An evening digest's cheat sheet is a list of em-dashed bullets; the
        // first bullet is the lede, without its marker.
        if let line = text.components(separatedBy: "\n").first(where: {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
        }) {
            text = line
        }
        for marker in ["\u{2014} ", "- ", "\u{2022} "] where text.hasPrefix(marker) {
            text = String(text.dropFirst(marker.count))
            break
        }

        // Digest prose carries Markdown emphasis the card does not render.
        text = text.replacingOccurrences(of: "**", with: "")
        text = text.replacingOccurrences(of: "__", with: "")

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Cuts at the last sentence that fits, so the card never ends mid-clause.
    private static func truncate(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }

        let head = String(text.prefix(limit))
        if let stop = head.lastIndex(where: { $0 == "." || $0 == "?" || $0 == "!" }) {
            let sentence = String(head[head.startIndex...stop])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            // A single very long sentence gives a useless stub; fall through
            // to the ellipsis rather than showing three words.
            if sentence.count >= limit / 3 { return sentence }
        }
        return head.trimmingCharacters(in: .whitespacesAndNewlines) + "\u{2026}"
    }
}
