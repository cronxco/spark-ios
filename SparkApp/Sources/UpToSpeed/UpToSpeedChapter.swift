import SparkUI
import SwiftUI

/// A named run of consecutive screens in the Up to Speed flow. Drives the
/// chaptered progress bar and the opener's chapter list.
struct UpToSpeedChapter: Identifiable {
    enum Kind: Equatable {
        case intro
        /// Carries the metric's domain so a bank balance is not filed under
        /// "Your body". Anomalies of different domains form separate chapters,
        /// because the run-length grouping treats unequal keys as a boundary.
        case anomaly(domain: String?)
        case digest(title: String)
        /// The roundup's few deep stories.
        case news
        /// Every individual article behind them, as a skimmable second tier.
        case headlines
        case wrap
        /// Everything already seen today, offered after the flow proper.
        case recap

        var shortLabel: String {
            switch self {
            case .intro: "Start"
            case .anomaly(let domain): Self.anomalyLabel(for: domain)
            case .digest: "Briefing"
            case .news: "News"
            case .headlines: "Headlines"
            case .wrap: "Wrap"
            case .recap: "Earlier"
            }
        }

        var accent: Color {
            switch self {
            case .intro: .sparkAccent
            case .anomaly(let domain): Self.anomalyAccent(for: domain)
            case .digest: .sparkAccent
            case .news: .sparkOcean
            case .headlines: .domainKnowledge
            case .wrap: .sparkSuccess
            case .recap: .secondary
            }
        }

        private static func anomalyLabel(for domain: String?) -> String {
            switch domain {
            case "health": "Your body"
            case "money": "Your money"
            case "media": "Your media"
            case "knowledge": "Your reading"
            case "online": "Online"
            default: "Unusual"
            }
        }

        private static func anomalyAccent(for domain: String?) -> Color {
            switch domain {
            case "health": .domainHealth
            case "money": .domainMoney
            case "media": .domainMedia
            case "knowledge": .domainKnowledge
            default: .sparkWarning
            }
        }
    }

    let id: String
    let kind: Kind
    /// Display title for the opener's chapter list.
    let title: String
    /// Global screen indices this chapter spans.
    let range: Range<Int>

    var shortLabel: String { kind.shortLabel }

    var accent: Color { kind.accent }
    var cardCount: Int { range.count }

    /// Groups a built screen queue into chapters by collapsing consecutive
    /// screens that share a chapter key.
    static func chapters(for keys: [Kind]) -> [UpToSpeedChapter] {
        var result: [UpToSpeedChapter] = []
        var start = 0

        while start < keys.count {
            let kind = keys[start]
            var end = start + 1
            while end < keys.count, keys[end] == kind { end += 1 }
            result.append(
                UpToSpeedChapter(
                    id: "\(result.count)-\(kind.shortLabel)",
                    kind: kind,
                    title: title(for: kind),
                    range: start..<end
                )
            )
            start = end
        }
        return result
    }

    private static func title(for kind: Kind) -> String {
        switch kind {
        // The opener leads with today's calendar and weather now, so it is
        // literally the day rather than an abstract orientation.
        case .intro: "Your day"
        // Not "Your readiness dip": the chapter holds whatever was unusual,
        // which is often neither readiness nor a dip — and, before the domain
        // was known, was as likely to be a bank balance as a health metric.
        case .anomaly: kind.shortLabel
        case .digest(let title): title
        case .news: "News roundup"
        case .headlines: "Also in your news"
        case .wrap: "Before you go"
        case .recap: "Already seen today"
        }
    }
}
