import Foundation

/// What a line typed into the CMD tab is meant to do.
public enum CmdIntent: String, Codable, CaseIterable, Sendable {
    case log
    case flintNote
    case command
    case search

    /// Terse chip label.
    public var label: String {
        switch self {
        case .log: "Log"
        case .flintNote: "Flint"
        case .command: "Command"
        case .search: "Search"
        }
    }

    public var systemImage: String {
        switch self {
        case .log: "text.append"
        case .flintNote: "sparkles"
        case .command: "chevron.left.forwardslash.chevron.right"
        case .search: "magnifyingglass"
        }
    }
}

/// The classifier's verdict on one line of input.
public struct CmdClassification: Equatable, Sendable {
    public let intent: CmdIntent
    /// 0...1. Below `CmdClassifier.askThreshold` the app asks before saving.
    public let confidence: Double
    /// The input with any forcing prefix or `@flint` handle removed.
    public let text: String
    /// True when a prefix (`/`, `?`) or `@flint` decided the intent.
    public let isForced: Bool

    public init(intent: CmdIntent, confidence: Double, text: String, isForced: Bool = false) {
        self.intent = intent
        self.confidence = confidence
        self.text = text
        self.isForced = isForced
    }

    public var needsAsk: Bool { confidence < CmdClassifier.askThreshold }
}

/// Classifies CMD input. The shipped implementation is on-device (PCC);
/// `HeuristicCmdClassifier` is the offline fallback and the stub until then.
public protocol CmdClassifying: Sendable {
    func classify(_ input: String) async -> CmdClassification?
}

public enum CmdClassifier {
    /// Below this the app asks which intent before writing anything.
    /// Open question in the plan: tune against real entries.
    public static let askThreshold = 0.6
}

/// Rules only: prefixes, `@flint`, a few command verbs, and a short-line
/// default to Log. Anything else lands under the threshold and asks.
public struct HeuristicCmdClassifier: CmdClassifying {
    private static let commandVerbs: Set<String> = ["sync", "refresh", "open", "show"]
    private static let ambiguousVerbs: Set<String> = ["run", "tag"]

    public init() {}

    public func classify(_ input: String) async -> CmdClassification? {
        Self.classifySync(input)
    }

    public static func classifySync(_ input: String) -> CmdClassification? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let stripped = stripFlintHandle(trimmed) {
            return CmdClassification(intent: .flintNote, confidence: 1, text: stripped, isForced: true)
        }
        if trimmed.hasPrefix("/") {
            return CmdClassification(
                intent: .command, confidence: 1, text: rest(of: trimmed, dropping: 1), isForced: true)
        }
        if trimmed.hasPrefix("?") {
            return CmdClassification(
                intent: .search, confidence: 1, text: rest(of: trimmed, dropping: 1), isForced: true)
        }

        let words = trimmed.split(whereSeparator: \.isWhitespace)
        let first = words.first?.lowercased() ?? ""
        if words.count >= 2, commandVerbs.contains(first) {
            return CmdClassification(intent: .command, confidence: 0.8, text: trimmed)
        }
        if words.count >= 2, ambiguousVerbs.contains(first) {
            return CmdClassification(intent: .command, confidence: 0.5, text: trimmed)
        }
        if trimmed.hasSuffix("?") {
            return CmdClassification(intent: .search, confidence: 0.7, text: trimmed)
        }
        if words.count <= 12 {
            return CmdClassification(intent: .log, confidence: 0.75, text: trimmed)
        }
        return CmdClassification(intent: .log, confidence: 0.5, text: trimmed)
    }

    /// `@flint` as a whole word, anywhere in the line. Nil when absent.
    /// `@flinton` is a person, not Flint.
    static func stripFlintHandle(_ text: String) -> String? {
        let pattern = #"(?<![\w@])@flint(?![\w])"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard regex.firstMatch(in: text, range: range) != nil else { return nil }
        let stripped = regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
        return stripped
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static func rest(of text: String, dropping count: Int) -> String {
        String(text.dropFirst(count)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
