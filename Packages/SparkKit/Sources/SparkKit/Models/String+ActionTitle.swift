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
