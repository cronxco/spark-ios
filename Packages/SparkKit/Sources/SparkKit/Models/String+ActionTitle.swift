import Foundation

public extension String {
    var sparkActionTitle: String {
        let headline = replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .map { word in
                let lower = word.lowercased()
                guard let first = lower.first else { return "" }
                return first.uppercased() + String(lower.dropFirst())
            }

        return headline.enumerated()
            .map { index, word in
                let lower = word.lowercased()
                if index != 0, Self.minorWords.contains(lower) {
                    return lower
                }
                return word
            }
            .joined(separator: " ")
    }

    private static var minorWords: Set<String> {
        [
            "and", "as", "but", "for", "if", "nor", "or", "so", "yet",
            "a", "an", "the",
            "about", "above", "across", "after", "against", "along", "among", "around",
            "at", "before", "behind", "below", "beneath", "beside", "besides", "between",
            "beyond", "by", "concerning", "considering", "despite", "down", "during",
            "except", "following", "from", "in", "inside", "into", "like", "near",
            "of", "off", "on", "onto", "opposite", "outside", "over", "past", "per",
            "plus", "regarding", "round", "since", "than", "through", "to", "toward",
            "under", "underneath", "unlike", "until", "up", "upon", "via", "with",
            "within", "without",
        ]
    }
}

public extension String {
    /// A raw identifier as sentence case: `sleep_summary` -> `Sleep summary`,
    /// `monzo` -> `Monzo`. Spark is sentence case throughout, so any snake or
    /// kebab identifier reaching the interface goes through this rather than
    /// being uppercased or title-cased.
    ///
    /// Only for machine-written identifiers. Text a person wrote is already
    /// cased and must be rendered as given — this would flatten its acronyms.
    var sparkSentenceCase: String {
        let words = replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .map { $0.lowercased() }

        guard let first = words.first, let initial = first.first else { return "" }
        let head = initial.uppercased() + String(first.dropFirst())
        return ([head] + words.dropFirst()).joined(separator: " ")
    }
}
