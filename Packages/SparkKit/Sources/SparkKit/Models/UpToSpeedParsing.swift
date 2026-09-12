import Foundation

/// One `## `-delimited section of a Flint news-roundup digest summary.
public struct NewsRoundupSection: Identifiable, Hashable, Sendable {
    public let id: Int
    /// Section heading — the story's headline.
    public let heading: String
    /// Publication names extracted from `*italic*` runs in the body.
    public let sources: [String]
    /// "New since yesterday" sentence, if the section carries one.
    public let whatsNew: String?
    /// Trailing "what I'm watching" sentence, if present.
    public let watching: String?
    /// The remaining prose (headline / whatsNew / watching removed).
    public let body: String

    public init(id: Int, heading: String, sources: [String], whatsNew: String?, watching: String?, body: String) {
        self.id = id
        self.heading = heading
        self.sources = sources
        self.whatsNew = whatsNew
        self.watching = watching
        self.body = body
    }
}

/// Pure text parsing for the Up to Speed flow — splitting the Flint news-roundup
/// summary into per-story sections and pulling a reading-list item out of the
/// reading-list digest. Free of view/model state so it can be unit-tested.
public enum UpToSpeedParsing {
    // MARK: - News roundup

    /// Splits a `## `-delimited markdown summary into one section per heading.
    /// Prose before the first heading is ignored.
    public static func newsRoundupSections(from summary: String) -> [NewsRoundupSection] {
        let lines = summary.components(separatedBy: "\n")
        var sections: [(heading: String, body: [String])] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("## ") {
                sections.append((heading: String(trimmed.dropFirst(3)), body: []))
            } else if !sections.isEmpty {
                sections[sections.count - 1].body.append(line)
            }
        }

        return sections.enumerated().map { index, section in
            let body = section.body
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let paragraphs = body
                .components(separatedBy: "\n\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            let whatsNew = paragraphs.first { $0.range(of: "new since yesterday", options: .caseInsensitive) != nil }
            let watching = sentences(in: body).first { sentence in
                let lowered = sentence.lowercased()
                return lowered.hasPrefix("watch for") || lowered.hasPrefix("watch ")
            }

            let remaining = paragraphs
                .filter { $0 != whatsNew }
                .map { paragraph -> String in
                    guard let watching else { return paragraph }
                    return paragraph.replacingOccurrences(of: watching, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .filter { !$0.isEmpty }
                .joined(separator: "\n\n")

            return NewsRoundupSection(
                id: index,
                heading: section.heading,
                sources: italicRuns(in: body),
                whatsNew: whatsNew.map(strippingWhatsNewPrefix),
                watching: watching,
                body: remaining
            )
        }
    }

    /// Publication names wrapped in `*single asterisks*` (not `**bold**`),
    /// de-duplicated in order.
    public static func italicRuns(in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"(?<!\*)\*([^*\n]+)\*(?!\*)"#) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        var results: [String] = []
        regex.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let match, match.numberOfRanges > 1,
                  let captured = Range(match.range(at: 1), in: text) else { return }
            let run = text[captured].trimmingCharacters(in: .whitespacesAndNewlines)
            if !run.isEmpty, !results.contains(run) {
                results.append(run)
            }
        }
        return results
    }

    private static func strippingWhatsNewPrefix(_ text: String) -> String {
        guard let range = text.range(of: "new since yesterday", options: .caseInsensitive) else { return text }
        let tail = text[range.upperBound...]
        // Remove only a complete "is" plus separators — not every leading run of
        // i/s characters, which previously ate into the following word (e.g.
        // "is slowing" → "lowing").
        let cleaned = String(tail).replacingOccurrences(
            of: #"^\s*(?:is\b\s*)?[:\-—]?\s*"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        let result = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { return text }
        return result.prefix(1).uppercased() + result.dropFirst()
    }

    private static func sentences(in text: String) -> [String] {
        text
            .replacingOccurrences(of: "\n", with: " ")
            .components(separatedBy: ". ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Reading list

    public struct ReadingItem: Equatable, Sendable {
        public var title: String
        public var url: String?
        public var readingTime: String?
        public var blurb: String?

        public init(title: String, url: String? = nil, readingTime: String? = nil, blurb: String? = nil) {
            self.title = title
            self.url = url
            self.readingTime = readingTime
            self.blurb = blurb
        }
    }

    /// Parses `**[Title](url)** — about 12 minutes. Blurb…` from the
    /// reading-list digest summary.
    public static func readingItem(from summary: String) -> ReadingItem? {
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var title = trimmed
        var url: String?
        if let open = trimmed.firstIndex(of: "["),
           let close = trimmed.firstIndex(of: "]"),
           open < close {
            title = String(trimmed[trimmed.index(after: open)..<close])
            let afterClose = trimmed[trimmed.index(after: close)...]
            if afterClose.first == "(", let paren = afterClose.firstIndex(of: ")") {
                url = String(afterClose[afterClose.index(after: afterClose.startIndex)..<paren])
            }
        } else {
            title = firstSentence(of: trimmed)
        }

        var readingTime: String?
        if let match = trimmed.range(
            of: #"(about )?\d+[\s-]?(min read|minutes?|mins?)"#,
            options: .regularExpression
        ) {
            let raw = String(trimmed[match])
            if let digits = raw.range(of: #"\d+"#, options: .regularExpression) {
                readingTime = "\(raw[digits]) min"
            }
        }

        var blurb: String?
        if let dash = trimmed.range(of: " — ") ?? trimmed.range(of: " – ") ?? trimmed.range(of: " - ") {
            let tail = trimmed[dash.upperBound...]
            let afterTime = tail
                .replacingOccurrences(
                    of: #"^(about )?\d+[\s-]?(min read|minutes?|mins?)\.?\s*"#,
                    with: "",
                    options: .regularExpression
                )
                .trimmingCharacters(in: .whitespacesAndNewlines)
            blurb = afterTime.isEmpty ? nil : afterTime
        }

        return ReadingItem(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            url: url,
            readingTime: readingTime,
            blurb: blurb
        )
    }

    // MARK: - Opener

    /// The first one or two body paragraphs of a digest summary, skipping a
    /// leading bare greeting line and any ALL-CAPS section headings.
    public static func openerParagraphs(from summary: String, limit: Int = 2) -> [String] {
        let chunks = summary
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var paragraphs: [String] = []
        for chunk in chunks {
            if isSectionHeading(chunk) { continue }
            if paragraphs.isEmpty, isBareGreeting(chunk) { continue }
            paragraphs.append(chunk)
            if paragraphs.count == limit { break }
        }
        return paragraphs
    }

    /// Whether a digest section has already been shown on the opener card.
    ///
    /// The opener leads with the digest's first body paragraphs, and the
    /// briefing chapter then rendered those same paragraphs again — so the
    /// reader met identical prose twice within a few swipes. A bare greeting
    /// counts as shown too: the opener carries it as the headline, which
    /// otherwise left the briefing's first card holding nothing but
    /// "Good Friday morning."
    public static func sectionIsShownInOpener(_ section: String, openerParagraphs: [String]) -> Bool {
        let body = sectionBody(section)

        if body.isEmpty { return true }
        if isBareGreeting(body) { return true }

        let normalised = normalisedForComparison(body)
        if openerParagraphs.contains(where: { normalisedForComparison($0) == normalised }) {
            return true
        }

        let joinedOpener = normalisedForComparison(openerParagraphs.joined(separator: "\n\n"))
        return !joinedOpener.isEmpty && joinedOpener == normalised
    }

    /// A section with its ALL-CAPS heading lines removed, leaving the prose.
    private static func sectionBody(_ section: String) -> String {
        section
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !isSectionHeading($0) }
            .joined(separator: "\n\n")
    }

    private static func normalisedForComparison(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func isSectionHeading(_ chunk: String) -> Bool {
        guard chunk.count < 80 else { return false }
        if chunk.hasPrefix("## ") { return true }
        let letters = chunk.filter(\.isLetter)
        guard !letters.isEmpty else { return false }
        return letters.allSatisfy(\.isUppercase)
    }

    private static func isBareGreeting(_ chunk: String) -> Bool {
        let weekday = #"(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)"#
        let timeOfDay = #"(?:morning|afternoon|evening)"#
        let pattern = #"^(?:good|happy) (?:(?:\#(weekday))(?: \#(timeOfDay))?|\#(timeOfDay)|weekend)[.!?]?$"#
        return chunk.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func firstSentence(of text: String) -> String {
        if let stop = text.firstIndex(where: { $0 == "." || $0 == "\n" }) {
            return String(text[..<stop])
        }
        return text
    }

    // MARK: - Yesterday recap

    /// A one-sentence recap of yesterday, pulled from the digest summary's
    /// "WHAT YOU'VE BEEN UP TO" section (the morning digest's retrospective
    /// paragraph) — the Day screen's "yesterday" mini-card. `nil` when the
    /// summary carries no such section (afternoon/evening digests, or a
    /// morning digest that omitted it as a quiet-day simplification).
    public static func yesterdayRecap(from summary: String) -> String? {
        let chunks = summary
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let headingIndex = chunks.firstIndex(where: isYesterdayHeading) else { return nil }
        let bodyIndex = chunks.index(after: headingIndex)
        guard chunks.indices.contains(bodyIndex) else { return nil }

        let sentence = firstSentence(of: chunks[bodyIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        return sentence.isEmpty ? nil : sentence
    }

    private static func isYesterdayHeading(_ chunk: String) -> Bool {
        chunk.range(of: "WHAT YOU'VE BEEN UP TO", options: .caseInsensitive) != nil
    }
}
