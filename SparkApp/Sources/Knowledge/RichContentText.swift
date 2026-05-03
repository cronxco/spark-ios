import SparkUI
import SwiftUI
import UIKit

struct RichContentText: View {
    let text: String
    var font: Font = SparkTypography.body
    var foregroundStyle: Color = .primary
    var lineSpacing: CGFloat = 4

    var body: some View {
        Text(Self.rendered(text))
            .font(font)
            .foregroundStyle(foregroundStyle)
            .lineSpacing(lineSpacing)
            .fixedSize(horizontal: false, vertical: true)
    }

    private static func rendered(_ text: String) -> AttributedString {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
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

        if let attributed = try? AttributedString(markdown: trimmed) {
            return attributed
        }

        return AttributedString(trimmed)
    }

    private static func looksLikeHTML(_ text: String) -> Bool {
        text.range(of: #"<[a-zA-Z][\s\S]*>"#, options: .regularExpression) != nil
    }
}
