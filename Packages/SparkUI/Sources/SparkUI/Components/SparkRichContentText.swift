import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

public struct SparkRichContentText: View {
    public let text: String
    public var font: Font
    public var foregroundStyle: Color
    public var lineSpacing: CGFloat

    public init(
        text: String,
        font: Font = SparkTypography.body,
        foregroundStyle: Color = .primary,
        lineSpacing: CGFloat = 6
    ) {
        self.text = text
        self.font = font
        self.foregroundStyle = foregroundStyle
        self.lineSpacing = lineSpacing
    }

    public var body: some View {
        Text(Self.rendered(text))
            .font(font)
            .foregroundStyle(foregroundStyle)
            .lineSpacing(lineSpacing)
            .fixedSize(horizontal: false, vertical: true)
    }

    public static func rendered(_ text: String) -> AttributedString {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        #if canImport(UIKit)
        if looksLikeHTML(trimmed),
           let data = trimmed.data(using: .utf8),
           let attributed = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue,
                ],
                documentAttributes: nil
           ) {
            return AttributedString(attributed)
        }
        #endif

        if let attributed = try? AttributedString(markdown: trimmed) {
            return attributed
        }

        return AttributedString(trimmed)
    }

    private static func looksLikeHTML(_ text: String) -> Bool {
        text.range(of: #"<[a-zA-Z][\s\S]*>"#, options: .regularExpression) != nil
    }
}

public struct SparkLongFormContentView: View {
    public let text: String
    public var tint: Color
    public var paragraphFont: Font

    private var blocks: [SparkLongFormBlock] {
        SparkLongFormBlock.parse(text)
    }

    public init(
        text: String,
        tint: Color = .sparkAccent,
        paragraphFont: Font = SparkTypography.longFormBody
    ) {
        self.text = text
        self.tint = tint
        self.paragraphFont = paragraphFont
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.lg) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .heading(let text, let level):
                    SparkRichContentText(
                        text: text,
                        font: level == 1
                            ? SparkFonts.display(.title2, weight: .bold)
                            : SparkFonts.display(.title3, weight: .bold),
                        foregroundStyle: .primary,
                        lineSpacing: 2
                    )
                    .padding(.top, level == 1 ? SparkSpacing.sm : SparkSpacing.xs)

                case .paragraph(let text):
                    SparkRichContentText(
                        text: text,
                        font: paragraphFont,
                        foregroundStyle: .primary,
                        lineSpacing: 9
                    )

                case .quote(let text):
                    HStack(alignment: .top, spacing: SparkSpacing.md) {
                        Rectangle()
                            .fill(tint)
                            .frame(width: 3)
                            .clipShape(.capsule)
                        SparkRichContentText(
                            text: text,
                            font: SparkTypography.longFormQuote,
                            foregroundStyle: .secondary,
                            lineSpacing: 9
                        )
                    }

                case .bullets(let bullets):
                    VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                        ForEach(bullets, id: \.self) { bullet in
                            HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.sm) {
                                Text("•")
                                    .font(SparkTypography.bodyStrong)
                                    .foregroundStyle(tint)
                                SparkRichContentText(
                                    text: bullet,
                                    font: paragraphFont,
                                    foregroundStyle: .primary,
                                    lineSpacing: 7
                                )
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, SparkSpacing.xs)
    }
}

public enum SparkLongFormBlock: Sendable, Hashable {
    case heading(String, level: Int)
    case paragraph(String)
    case quote(String)
    case bullets([String])

    public static func parse(_ text: String) -> [SparkLongFormBlock] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return [] }

        let rawBlocks = normalized.components(separatedBy: "\n\n")
        var output: [SparkLongFormBlock] = []

        for rawBlock in rawBlocks {
            let trimmed = rawBlock.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let lines = trimmed
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            guard !lines.isEmpty else { continue }

            if lines.count == 1, let heading = heading(from: lines[0]) {
                output.append(.heading(heading.text, level: heading.level))
                continue
            }

            if lines.allSatisfy({ $0.hasPrefix(">") }) {
                let text = lines
                    .map { String($0.drop(while: { $0 == ">" || $0 == " " })) }
                    .joined(separator: "\n")
                output.append(.quote(text))
                continue
            }

            if lines.allSatisfy(isBulletLine) {
                output.append(.bullets(lines.map(stripBulletPrefix)))
                continue
            }

            output.append(.paragraph(lines.joined(separator: "\n")))
        }

        return output
    }

    private static func heading(from line: String) -> (text: String, level: Int)? {
        if line.hasPrefix("### ") {
            return (String(line.dropFirst(4)), 3)
        }
        if line.hasPrefix("## ") {
            return (String(line.dropFirst(3)), 2)
        }
        if line.hasPrefix("# ") {
            return (String(line.dropFirst(2)), 1)
        }
        return nil
    }

    private static func isBulletLine(_ line: String) -> Bool {
        line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ")
    }

    private static func stripBulletPrefix(_ line: String) -> String {
        if isBulletLine(line) {
            return String(line.dropFirst(2))
        }
        return line
    }
}
