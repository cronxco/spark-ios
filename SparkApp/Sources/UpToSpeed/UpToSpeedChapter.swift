import SparkUI
import SwiftUI

/// A named run of consecutive screens in the Up to Speed flow. Drives the
/// chaptered progress bar and the opener's chapter list.
struct UpToSpeedChapter: Identifiable {
    enum Kind: Equatable {
        case intro
        case anomaly
        case digest(title: String)
        case day
        case news
        case wrap

        var shortLabel: String {
            switch self {
            case .intro: "Start"
            case .anomaly: "Your body"
            case .digest: "Briefing"
            case .day: "Day"
            case .news: "News"
            case .wrap: "Wrap"
            }
        }

        var accent: Color {
            switch self {
            case .intro: .sparkAccent
            case .anomaly: .sparkWarning
            case .digest: .sparkAccent
            case .day: .sparkAccent
            case .news: .sparkOcean
            case .wrap: .sparkSuccess
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
        case .intro: "Where you are"
        case .anomaly: "Your readiness dip"
        case .digest(let title): title
        case .day: "Your day"
        case .news: "News roundup"
        case .wrap: "Before you go"
        }
    }
}
