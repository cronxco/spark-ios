import Foundation

/// One block of a Markdown text: a paragraph, heading, list item, quote, code
/// block, rule or table row, with its inline styling and links kept.
public struct MarkdownBlock: Equatable, Identifiable {
    public enum Kind: Equatable, Sendable {
        case paragraph
        case heading(level: Int)
        /// `marker` is "•" for a bullet or "3." for an ordered item. It is nil
        /// for a second paragraph inside the same item, which takes the item's
        /// indent and no marker. `depth` starts at 1.
        case listItem(marker: String?, depth: Int)
        case quote
        case code(language: String?)
        case rule
        /// One row of a table; the row's text is its cells joined with tabs.
        case tableRow(isHeader: Bool)
    }

    public let id: Int
    public let kind: Kind
    public let content: AttributedString
    /// The cells of a table row, in column order. Empty for any other block.
    public let cells: [AttributedString]

    public init(id: Int, kind: Kind, content: AttributedString, cells: [AttributedString] = []) {
        self.id = id
        self.kind = kind
        self.content = content
        self.cells = cells
    }

    public var plainText: String { String(content.characters) }
}

/// Reads Markdown into blocks.
///
/// `AttributedString(markdown:)` with full syntax marks each paragraph, list
/// item and heading with a `presentationIntent` but leaves no line break
/// between them, and a SwiftUI `Text` ignores presentation intents. Drawn as
/// one `Text`, "picks up:\n\n- **Sun 22:** …" reads "picks up:Sun 22: …".
/// This splits the parsed text back into its blocks, so a view can lay each
/// out, or `flattened` can put the breaks back for a single `Text`.
public enum MarkdownBlocks {
    public static func parse(_ markdown: String) -> [MarkdownBlock] {
        let source = withLineBreaks(markdown.replacingOccurrences(of: "\r\n", with: "\n"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { return [] }

        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        guard let parsed = try? AttributedString(markdown: source, options: options) else {
            return [MarkdownBlock(id: 0, kind: .paragraph, content: AttributedString(source))]
        }

        var blocks: [MarkdownBlock] = []
        var lastListItem: Int?
        var row: (identity: Int, isHeader: Bool, cells: [AttributedString])?

        func flushRow() {
            guard let current = row else { return }
            var joined = AttributedString()
            for (index, cell) in current.cells.enumerated() {
                if index > 0 { joined.append(AttributedString("\t")) }
                joined.append(cell)
            }
            blocks.append(MarkdownBlock(
                id: blocks.count, kind: .tableRow(isHeader: current.isHeader), content: joined, cells: current.cells))
            row = nil
        }

        for (intent, range) in parsed.runs[\.presentationIntent] {
            var content = AttributedString(parsed[range])
            let components = intent?.components ?? []

            if let rowComponent = components.first(where: { $0.kind.isTableRow }) {
                if row?.identity != rowComponent.identity {
                    flushRow()
                    row = (rowComponent.identity, rowComponent.kind == .tableHeaderRow, [])
                }
                row?.cells.append(trimmed(content))
                continue
            }
            flushRow()

            let kind: MarkdownBlock.Kind
            if let code = components.first(where: { $0.kind.isCodeBlock }) {
                if case .codeBlock(let hint) = code.kind {
                    kind = .code(language: hint.flatMap { $0.isEmpty ? nil : $0 })
                } else {
                    kind = .code(language: nil)
                }
                content = trimmingTrailingNewlines(content)
            } else if components.contains(where: { $0.kind == .thematicBreak }) {
                kind = .rule
            } else if let header = components.first(where: { $0.kind.headerLevel != nil }) {
                kind = .heading(level: header.kind.headerLevel ?? 1)
                content = trimmed(content)
            } else if let itemIndex = components.firstIndex(where: { $0.kind.listOrdinal != nil }) {
                let item = components[itemIndex]
                let depth = components.filter { $0.kind == .orderedList || $0.kind == .unorderedList }.count
                let isOrdered = components[(itemIndex + 1)...].first {
                    $0.kind == .orderedList || $0.kind == .unorderedList
                }?.kind == .orderedList
                let marker: String? = lastListItem == item.identity
                    ? nil
                    : (isOrdered ? "\(item.kind.listOrdinal ?? 1)." : "•")
                lastListItem = item.identity
                kind = .listItem(marker: marker, depth: max(depth, 1))
                content = trimmed(content)
            } else if components.contains(where: { $0.kind == .blockQuote }) {
                kind = .quote
                content = trimmed(content)
            } else {
                kind = .paragraph
                content = trimmed(content)
            }

            if case .listItem = kind {} else { lastListItem = nil }
            blocks.append(MarkdownBlock(id: blocks.count, kind: kind, content: content))
        }
        flushRow()

        return blocks
    }

    /// The blocks as one attributed string with their breaks back: a blank
    /// line between paragraphs, one line between list items, a marker before
    /// each item and bold headings. For places that draw Flint's text in a
    /// single `Text`.
    public static func flattened(_ markdown: String) -> AttributedString {
        flattened(parse(markdown))
    }

    public static func flattened(_ blocks: [MarkdownBlock]) -> AttributedString {
        var result = AttributedString()
        var previous: MarkdownBlock.Kind?

        for block in blocks {
            if let previous {
                result.append(AttributedString(separator(after: previous, before: block.kind)))
            }

            switch block.kind {
            case .heading:
                var heading = block.content
                for run in heading.runs {
                    heading[run.range].inlinePresentationIntent = (run.inlinePresentationIntent ?? []).union(.stronglyEmphasized)
                }
                result.append(heading)
            case .listItem(let marker, let depth):
                let indent = String(repeating: "    ", count: depth - 1)
                result.append(AttributedString(indent + (marker.map { "\($0) " } ?? "   ")))
                result.append(block.content)
            case .rule:
                result.append(AttributedString("———"))
            default:
                result.append(block.content)
            }
            previous = block.kind
        }

        return result
    }

    private static func separator(after previous: MarkdownBlock.Kind, before next: MarkdownBlock.Kind) -> String {
        switch (previous, next) {
        case (.listItem, .listItem), (.tableRow, .tableRow):
            "\n"
        case (.heading, _):
            "\n"
        default:
            "\n\n"
        }
    }

    /// Chat models write a line break where they mean one, as people do in
    /// messages; Markdown would fold it into a space. Each lone newline inside
    /// running text becomes a hard break. Blank lines, fenced code and lines
    /// that start a list, heading, quote or table are left alone.
    static func withLineBreaks(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        guard lines.count > 1 else { return text }

        var output: [String] = []
        var openFence: (character: Character, length: Int)?

        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if let marker = fence(in: trimmedLine) {
                if let open = openFence {
                    let closes = marker.character == open.character
                        && marker.length >= open.length
                        && trimmedLine.dropFirst(marker.length).allSatisfy(\.isWhitespace)
                    if closes { openFence = nil }
                } else {
                    openFence = marker
                }
                output.append(line)
                continue
            }
            let inFence = openFence != nil

            let next = index + 1 < lines.count ? lines[index + 1].trimmingCharacters(in: .whitespaces) : ""
            let breaks = !inFence
                && !trimmedLine.isEmpty
                && !next.isEmpty
                && !startsBlock(next)
                && !trimmedLine.hasPrefix("|")
                && !trimmedLine.hasSuffix("  ")
                && !trimmedLine.hasSuffix("\\")
                && !isHeadingOrRule(trimmedLine)
                && !isSetextUnderline(next)

            output.append(breaks ? line + "  " : line)
        }

        return output.joined(separator: "\n")
    }

    /// The fence character and run length when the line opens or closes a
    /// fenced code block: three or more backticks or tildes.
    private static func fence(in line: String) -> (character: Character, length: Int)? {
        guard let first = line.first, first == "`" || first == "~" else { return nil }
        let length = line.prefix(while: { $0 == first }).count
        return length >= 3 ? (first, length) : nil
    }

    /// An ATX heading: one to six `#` and then a space or the end of the line.
    private static func isHeading(_ line: String) -> Bool {
        line.range(of: #"^#{1,6}(\s|$)"#, options: .regularExpression) != nil
    }

    private static func startsBlock(_ line: String) -> Bool {
        if isHeading(line) || line.hasPrefix(">") || line.hasPrefix("|") || line.hasPrefix("```") || line.hasPrefix("~~~") {
            return true
        }
        if ["- ", "* ", "+ "].contains(where: { line.hasPrefix($0) }) { return true }
        if line.range(of: #"^\d{1,3}[.)]\s"#, options: .regularExpression) != nil { return true }
        return isHeadingOrRule(line)
    }

    private static func isHeadingOrRule(_ line: String) -> Bool {
        isHeading(line) || line.range(of: #"^([-*_])(\s*\1){2,}\s*$"#, options: .regularExpression) != nil
    }

    private static func isSetextUnderline(_ line: String) -> Bool {
        line.range(of: #"^(=+|-+)\s*$"#, options: .regularExpression) != nil
    }

    private static func trimmed(_ text: AttributedString) -> AttributedString {
        trimmingTrailingNewlines(trimmingLeadingNewlines(text))
    }

    private static func trimmingTrailingNewlines(_ text: AttributedString) -> AttributedString {
        var text = text
        while let last = text.characters.last, last.isNewline {
            text.removeSubrange(text.characters.index(before: text.endIndex)..<text.endIndex)
        }
        return text
    }

    private static func trimmingLeadingNewlines(_ text: AttributedString) -> AttributedString {
        var text = text
        while let first = text.characters.first, first.isNewline {
            text.removeSubrange(text.startIndex..<text.characters.index(after: text.startIndex))
        }
        return text
    }
}

private extension PresentationIntent.Kind {
    var isTableRow: Bool {
        switch self {
        case .tableRow, .tableHeaderRow: true
        default: false
        }
    }

    var isCodeBlock: Bool {
        if case .codeBlock = self { return true }
        return false
    }

    var headerLevel: Int? {
        if case .header(let level) = self { return level }
        return nil
    }

    var listOrdinal: Int? {
        if case .listItem(let ordinal) = self { return ordinal }
        return nil
    }
}
