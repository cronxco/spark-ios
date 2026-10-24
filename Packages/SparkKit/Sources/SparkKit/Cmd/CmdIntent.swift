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
    /// `@mentions` the server matched to people. Empty offline.
    public let mentions: [CmdMention]

    public init(
        intent: CmdIntent, confidence: Double, text: String, isForced: Bool = false,
        mentions: [CmdMention] = []
    ) {
        self.intent = intent
        self.confidence = confidence
        self.text = text
        self.isForced = isForced
        self.mentions = mentions
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
    public static let askThreshold = 0.7
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

/// An `@mention` and who it could mean.
public struct CmdMention: Equatable, Identifiable, Sendable {
    public enum State: String, Sendable {
        /// The name is a person already.
        case existing
        /// One person starts with it (`@dan`, Daniel).
        case likely
        /// Several people do: the user picks.
        case ambiguous
        /// Nobody does.
        case new
    }

    public struct Match: Equatable, Sendable {
        public let id: String
        public let name: String

        public init(id: String, name: String) {
            self.id = id
            self.name = name
        }
    }

    public let name: String
    public let state: State
    public let matches: [Match]

    public var id: String { name }

    public init(name: String, state: State, matches: [Match]) {
        self.name = name
        self.state = state
        self.matches = matches
    }

    /// The name a new person is created with: how it was typed, with a
    /// lower-case handle (the server folds case) capitalised.
    public var displayName: String {
        name.contains(where: \.isUppercase)
            ? name
            : name.split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }
}

/// What the user chose for an ambiguous mention.
public enum CmdMentionPick: Equatable, Sendable {
    case person(id: String)
    case createNew
}

/// Who a log line is linked to, settled from its mentions.
public struct CmdPersonLinks: Equatable, Sendable {
    public var ids: [String]
    public var newNames: [String]

    public init(ids: [String] = [], newNames: [String] = []) {
        self.ids = ids
        self.newNames = newNames
    }

    /// The first ambiguous mention nobody has picked for yet.
    public static func unresolved(_ mentions: [CmdMention], picks: [String: CmdMentionPick]) -> CmdMention? {
        mentions.first { $0.state == .ambiguous && picks[$0.name] == nil }
    }

    /// Existing and likely people link by id, nobody-matches become new
    /// people, and an ambiguous mention uses the user's pick. Nil while one
    /// is still unpicked.
    public static func resolve(_ mentions: [CmdMention], picks: [String: CmdMentionPick]) -> CmdPersonLinks? {
        guard unresolved(mentions, picks: picks) == nil else { return nil }
        var links = CmdPersonLinks()
        for mention in mentions {
            switch mention.state {
            case .existing, .likely:
                if let match = mention.matches.first, !links.ids.contains(match.id) { links.ids.append(match.id) }
            case .new:
                links.addNew(mention.displayName)
            case .ambiguous:
                switch picks[mention.name] {
                case .person(let id): if !links.ids.contains(id) { links.ids.append(id) }
                case .createNew: links.addNew(mention.displayName)
                case nil: break
                }
            }
        }
        return links
    }

    private mutating func addNew(_ name: String) {
        if !newNames.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) { newNames.append(name) }
    }
}
