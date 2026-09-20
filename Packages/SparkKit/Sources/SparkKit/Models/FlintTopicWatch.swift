import Foundation

public extension FlintTopic {
    /// The one sentence of a thread worth putting on a home screen: what would
    /// move it on.
    ///
    /// Every thread's running summary is written to end that way — "the
    /// decisive next developments are a G7 decision on reserves…", "resolve
    /// once it has taken place" — so the closing sentence says what Flint is
    /// watching for on your behalf. The rest of the summary is the history,
    /// which belongs on the thread's own screen.
    var watchingFor: String? { Self.watchingFor(in: content) }

    static func watchingFor(in content: String?, limit: Int = 160) -> String? {
        guard let content else { return nil }
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        let sentences = sentences(in: text)
        guard let last = sentences.last else { return nil }

        // A short closer ("It is complete.") carries nothing on its own, so
        // reach back one sentence for the substance.
        var result = last
        if last.count < 40, sentences.count >= 2 {
            result = sentences[sentences.count - 2] + " " + last
        }

        if result.count > limit {
            result = String(result.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines) + "\u{2026}"
        }
        return result
    }

    private static func sentences(in text: String) -> [String] {
        var out: [String] = []
        var current = ""
        for character in text {
            current.append(character)
            if character == "." || character == "!" || character == "?" {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { out.append(trimmed) }
                current = ""
            }
        }
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { out.append(tail) }
        return out
    }
}
