import Foundation
import SparkKit

/// The words the preview uses for what was understood.
enum LogPreviewFormat {
    /// The Type switcher's order: a plain note first, then the kinds that are matched and enriched.
    static let kindOrder: [LogKind] = [.reflection, .tv, .cinema, .wine, .beer, .boardGame]

    /// Episode numbers from "7, 8", "7 and 8" or "7-9". Nil when none are given.
    static func episodeNumbers(from text: String) -> [Int]? {
        var numbers: [Int] = []
        for part in text.split(whereSeparator: { $0 == "," || $0 == " " }) {
            let bounds = part.split(whereSeparator: { $0 == "-" || $0 == "–" }).compactMap { Int($0) }
            if bounds.count == 2, bounds[0] <= bounds[1], bounds[1] - bounds[0] < 50 {
                numbers.append(contentsOf: bounds[0]...bounds[1])
            } else if bounds.count == 1 {
                numbers.append(bounds[0])
            }
        }
        let valid = Array(Set(numbers.filter { (1...999).contains($0) })).sorted().prefix(50)
        return valid.isEmpty ? nil : Array(valid)
    }

    static func kindName(_ kind: LogKind) -> String {
        switch kind {
        case .wine: "Wine"
        case .beer: "Beer"
        case .tv: "TV"
        case .cinema: "Film"
        case .boardGame: "Board game"
        case .reflection: "Note"
        }
    }

    static func kindSymbol(_ kind: LogKind) -> String {
        switch kind {
        case .wine: "wineglass"
        case .beer: "mug"
        case .tv: "tv"
        case .cinema: "film"
        case .boardGame: "dice"
        case .reflection: "text.quote"
        }
    }

    /// "½ bottle", "1 can", "1 draft · 568 ml". Nil when nothing about the amount was said.
    static func amount(_ request: LogRequest) -> String? {
        var parts: [String] = []
        if let quantity = request.quantity {
            parts.append(fraction(quantity))
        }
        if let unit = request.unit {
            parts.append(unit)
        } else if let serving = request.serving {
            parts.append(serving.rawValue)
        }
        var text = parts.joined(separator: " ")
        if let volume = request.volumeML {
            text += text.isEmpty ? "\(volume) ml" : " · \(volume) ml"
        }
        return text.isEmpty ? nil : text
    }

    /// 0.5 is "½", 1.5 is "1½", 2 is "2".
    static func fraction(_ value: Double) -> String {
        let whole = Int(value.rounded(.down))
        let remainder = value - Double(whole)
        if abs(remainder) < 0.01 { return "\(whole)" }
        if abs(remainder - 0.5) < 0.01 { return whole == 0 ? "½" : "\(whole)½" }
        if abs(remainder - 0.25) < 0.01 { return whole == 0 ? "¼" : "\(whole)¼" }
        if abs(remainder - 0.75) < 0.01 { return whole == 0 ? "¾" : "\(whole)¾" }
        return value.formatted(.number.precision(.fractionLength(0...2)))
    }

    /// "E1–2", "E1, E4, E5". Consecutive episodes become a range.
    static func episodes(_ numbers: [Int]) -> String {
        let sorted = Array(Set(numbers)).sorted()
        var ranges: [ClosedRange<Int>] = []
        for number in sorted {
            if let last = ranges.last, last.upperBound + 1 == number {
                ranges[ranges.count - 1] = last.lowerBound...number
            } else {
                ranges.append(number...number)
            }
        }
        return ranges
            .map { $0.lowerBound == $0.upperBound ? "E\($0.lowerBound)" : "E\($0.lowerBound)–\($0.upperBound)" }
            .joined(separator: ", ")
    }

    /// "Now", "Today, 8:00 pm", "Yesterday, 8:00 pm", "Sat 17 Oct, 1:00 pm".
    static func when(_ date: Date?, now: Date = .now, calendar: Calendar = .current) -> String {
        guard let date else { return "Now" }

        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDate(date, inSameDayAs: now) { return "Today, \(time)" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday, \(time)"
        }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
    }
}
