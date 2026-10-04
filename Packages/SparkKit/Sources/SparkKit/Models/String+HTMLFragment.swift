import Foundation

public extension String {
    var sparkPlainTextFromHTMLFragment: String {
        SparkHTMLFragmentText.plainText(from: self)
    }
}

private enum SparkHTMLFragmentText {
    static func plainText(from html: String) -> String {
        var text = html.decodingHTMLEntities()
        text = text.replacingHTMLMatches(pattern: #"(?is)<(script|style)\b[^>]*>.*?</\1>"#, with: " ")
        text = text.replacingHTMLMatches(pattern: #"(?s)<!--.*?-->"#, with: " ")
        text = text.replacingHTMLMatches(pattern: #"(?i)<br\s*/?>"#, with: " ")
        text = text.replacingHTMLMatches(pattern: #"(?i)</?(p|div|li|tr|section|article|h[1-6])\b[^>]*>"#, with: " ")
        text = text.replacingHTMLMatches(pattern: #"<[^>]+>"#, with: "")
        text = text.decodingHTMLEntities()
        text = text.replacingOccurrences(of: "\u{00a0}", with: " ")
        text = text.replacingHTMLMatches(pattern: #"\s+"#, with: " ")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension String {
    func replacingHTMLMatches(pattern: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return self }
        let range = NSRange(startIndex..<endIndex, in: self)
        return regex.stringByReplacingMatches(in: self, range: range, withTemplate: template)
    }

    func decodingHTMLEntities() -> String {
        let namedEntities = [
            "amp": "&",
            "apos": "'",
            "gt": ">",
            "lt": "<",
            "nbsp": " ",
            "quot": "\""
        ]

        var text = self
        for (entity, value) in namedEntities {
            text = text.replacingOccurrences(of: "&\(entity);", with: value)
        }

        guard let regex = try? NSRegularExpression(pattern: #"&#(x[0-9A-Fa-f]+|\d+);"#) else {
            return text
        }

        let mutable = NSMutableString(string: text)
        let range = NSRange(location: 0, length: mutable.length)
        let matches = regex.matches(in: text, range: range)
        for match in matches.reversed() {
            let raw = mutable.substring(with: match.range(at: 1))
            let codePoint: UInt32?
            if raw.lowercased().hasPrefix("x") {
                codePoint = UInt32(raw.dropFirst(), radix: 16)
            } else {
                codePoint = UInt32(raw, radix: 10)
            }

            guard let codePoint, let scalar = UnicodeScalar(codePoint) else { continue }
            mutable.replaceCharacters(in: match.range, with: String(Character(scalar)))
        }

        return mutable as String
    }
}
