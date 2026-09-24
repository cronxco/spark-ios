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
    public var fullRoundup: String? = nil
    public var analysis: String? = nil
    public var references: [EntityReference] = []
    public var sourceURL: String? = nil
    public var sourcePositions: [FlintNewsSource] = []
    public var whyItMatters: String? = nil

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

    /// The roundup's stories, taken from its `flint_news` blocks where they
    /// exist and recovered from the summary prose where they do not.
    ///
    /// The blocks are what the skill actually wrote: a headline, a standalone
    /// distillation, and the sources it drew on. Splitting the prose on `## `
    /// and inferring publications from `*italic*` runs was reconstructing all
    /// of that from the rendering, and it broke silently whenever the wording
    /// changed. The parser stays as a fallback for digests written before the
    /// blocks existed.
    public static func newsRoundupSections(
        blocks: [FlintDigestBlock],
        summary: String
    ) -> [NewsRoundupSection] {
        let stories = blocks.filter { $0.blockType == "flint_news" }

        guard !stories.isEmpty else {
            return newsRoundupSections(from: summary)
        }

        return stories.enumerated().map { index, block in
            let body = (block.news?.summary ?? block.content)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            // `whatsNew` and `watching` belong to the long prose section. A
            // block is already the short version, so claiming to have found
            // them here would be inventing structure that isn't there.
            var section = NewsRoundupSection(
                id: index,
                heading: block.title,
                sources: block.news?.sources.map(\.publication) ?? italicRuns(in: body),
                whatsNew: nil,
                watching: block.news?.whatToWatch,
                body: body
            )
            section.sourcePositions = block.news?.sources ?? []
            section.whyItMatters = block.news?.whyItMatters
            section.fullRoundup = summary.isEmpty ? nil : summary
            section.references = block.references ?? []
            section.sourceURL = block.url
            return section
        }
    }

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

    /// Every pick in a reading-list digest, from its `flint_reading_pick`
    /// blocks where they exist and from the summary prose where they do not.
    ///
    /// Drops are deliberately excluded. In prose a `**Worth dropping:**` line
    /// is shaped exactly like a pick, so the regex below could offer something
    /// to delete as something to read; the block type settles it.
    ///
    /// Returns every pick rather than the first. The prose parser could only
    /// ever recover one, so a digest with two picks showed one of them.
    public static func readingItems(
        blocks: [FlintDigestBlock],
        summary: String
    ) -> [ReadingItem] {
        let picks = blocks.filter { $0.blockType == "flint_reading_pick" }

        guard !picks.isEmpty else {
            return readingItem(from: summary).map { [$0] } ?? []
        }

        return picks.map { block in
            ReadingItem(
                title: block.title,
                url: block.url,
                readingTime: block.minutes.map { "\($0) min" },
                blurb: block.content?.trimmingCharacters(in: .whitespacesAndNewlines)
            )
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

    // MARK: - Digest cards

    /// A digest summary split into the cards the briefing chapter shows.
    ///
    /// A heading chunk (ALL-CAPS, or `## `) belongs with the prose that follows
    /// it, so the two arrive together. A bare greeting is dropped — the opener
    /// carries its own, and a card holding nothing but "Good Saturday evening."
    /// is a whole screen for two words.
    ///
    /// A section whose body is one bullet list longer than `maxBullets` is split
    /// into balanced runs, with the heading kept on the first card only. Prose is
    /// never split: scrolling a paragraph is fine, scrolling a list of unrelated
    /// facts is how the 12 September cheat sheet became one wall of text.
    public static func digestCards(from summary: String, maxBullets: Int = 4) -> [String] {
        sections(in: summary).flatMap { section -> [String] in
            let body = sectionBody(section)
            guard !body.isEmpty, !isBareGreeting(body) else { return [] }
            return splitSection(section, maxBullets: maxBullets)
        }
    }

    /// Double-newline chunks, each heading merged into the body that follows it.
    private static func sections(in text: String) -> [String] {
        var sections: [String] = []
        var pending: [String] = []

        for chunk in chunks(of: text) {
            pending.append(chunk)
            if !isSectionHeading(chunk) {
                sections.append(pending.joined(separator: "\n\n"))
                pending = []
            }
        }

        if !pending.isEmpty {
            sections.append(pending.joined(separator: "\n\n"))
        }

        return sections
    }

    /// One card, unless the section is a long bullet list.
    private static func splitSection(_ section: String, maxBullets: Int) -> [String] {
        let parts = chunks(of: section)
        let heading = parts.first.flatMap { isSectionHeading($0) ? $0 : nil }
        let bodyChunks = heading == nil ? parts : Array(parts.dropFirst())

        // Only a section that is entirely one list can be split. Splitting one
        // with prose around it would shuffle the prose out of its place.
        guard bodyChunks.count == 1, let body = bodyChunks.first else {
            return [section]
        }

        let lines = body
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard lines.count > maxBullets, lines.allSatisfy(MarkdownList.isBullet) else {
            return [section]
        }

        return balancedRuns(lines, maxPerRun: maxBullets).enumerated().map { index, run in
            let text = run.joined(separator: "\n")
            guard index == 0, let heading else { return text }
            return heading + "\n\n" + text
        }
    }

    /// As few runs as possible, then evened out — six bullets at a maximum of
    /// four come out 3+3, not 4+2, so no card reads as the leftovers of the one
    /// before it.
    private static func balancedRuns(_ lines: [String], maxPerRun: Int) -> [[String]] {
        let runCount = max(1, Int((Double(lines.count) / Double(maxPerRun)).rounded(.up)))
        var runs: [[String]] = []
        var start = 0

        for index in 0..<runCount {
            let remaining = lines.count - start
            let size = Int((Double(remaining) / Double(runCount - index)).rounded(.up))
            runs.append(Array(lines[start..<(start + size)]))
            start += size
        }

        return runs
    }

    private static func chunks(of text: String) -> [String] {
        text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// A section with its heading lines removed, leaving the prose.
    private static func sectionBody(_ section: String) -> String {
        chunks(of: section)
            .filter { !isSectionHeading($0) }
            .joined(separator: "\n\n")
    }

    private static func isSectionHeading(_ chunk: String) -> Bool {
        guard chunk.count < 80 else { return false }
        if chunk.hasPrefix("## ") { return true }
        let letters = chunk.filter(\.isLetter)
        guard !letters.isEmpty else { return false }
        return letters.allSatisfy(\.isUppercase)
    }

    /// A standalone "Good Saturday evening." with nothing else in it. Public
    /// because the flow drops these wherever they appear: the opener already
    /// greets the reader in its own voice.
    public static func isBareGreeting(_ chunk: String) -> Bool {
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
        let chunks = chunks(of: summary)

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
