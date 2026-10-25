import Foundation
import FoundationModels
import SparkKit

/// What the model reads out of a line like "just had half a bottle of Cafe François Rouge".
/// It carries only what the user said; `LogDraft.request(...)` decides whether that is enough to log.
@Generable
struct LogDraft {
    @Guide(description: "What it was. Exactly one of: wine, beer, tv, cinema, boardGame, none. none if the line is about something else.")
    var kind: String

    @Guide(description: "Only the name of the wine, beer, show, film or game. No quantity, serving, verbs or episode numbers. Empty for none.")
    var title: String

    @Guide(description: "How many were had. 1 if unsaid, 0.5 for half. Empty for tv, cinema and boardGame.")
    var quantity: Double?

    @Guide(description: "Wine only: the unit that quantity counts, such as bottle or glass. Empty if unsaid.")
    var unit: String?

    @Guide(description: "Beer only: how it was served. One of: draft, cask, can, bottle, crowler, growler, taster. Empty if unsaid.")
    var serving: String?

    @Guide(description: "Exact volume in millilitres when stated or implied: half a pint is 284, a pint is 568. Empty if unsaid.")
    var volumeML: Int?

    @Guide(description: "tv only: the season number, only if the user said it. Empty otherwise.")
    var season: Int?

    @Guide(description: "tv only: the episode numbers watched. Episodes 1 and 2 is [1, 2]. Empty if unsaid.")
    var episodes: [Int]?

    @Guide(description: "How many minutes before now it happened. Empty for now, just now or unsaid.")
    var minutesAgo: Int?

    @Guide(description: "The words the user used for when it happened, copied as written: yesterday at 8pm, last night, this morning, Saturday lunch. Empty if unsaid.")
    var when: String?

    @Guide(description: "Stars out of 5 only if the user gave a rating, such as gave it 4 stars or rated it 8 out of 10 (4). Empty otherwise.")
    var rating: Double?

    @Guide(description: "Names of the people it was shared with, as written. Dan and Sam gives [Dan, Sam]. Empty if unsaid.")
    var people: [String]?
}

/// Why a draft cannot be logged yet.
enum LogDraftIssue: Error, Equatable {
    case unknownKind
    case missingTitle
    case missingEpisodes
}

extension LogDraft {
    /// The request for the backend, or the reason the draft is not enough.
    /// Values the backend would reject are dropped here rather than failing the whole entry.
    /// A line about anything else becomes a reflection of `text`, as typed, with the time and people read from it.
    func request(text: String = "", now: Date = .now, idempotencyKey: String = UUID().uuidString) throws -> LogRequest {
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if kind.lowercased().filter(\.isLetter) == "none" {
            guard !line.isEmpty else { throw LogDraftIssue.unknownKind }
            return LogRequest(
                kind: .reflection,
                idempotencyKey: idempotencyKey,
                title: "",
                occurredAt: occurredAt(now: now),
                people: names.isEmpty ? nil : names,
                body: line
            )
        }
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw LogDraftIssue.missingTitle }
        guard let logKind = LogKind(modelValue: kind), logKind != .reflection else { throw LogDraftIssue.unknownKind }
        var episodeNumbers: [Int]?
        if logKind == .tv {
            let numbers = Array(Set((episodes ?? []).filter { (1...999).contains($0) })).sorted().prefix(50)
            guard !numbers.isEmpty else { throw LogDraftIssue.missingEpisodes }
            episodeNumbers = Array(numbers)
        }

        return LogRequest(
            kind: logKind,
            idempotencyKey: idempotencyKey,
            title: name,
            occurredAt: occurredAt(now: now),
            quantity: quantity.flatMap { $0 > 0 && $0 <= 100 ? $0 : nil },
            unit: unit?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            serving: logKind == .beer ? serving.flatMap(LogServing.init(modelValue:)) : nil,
            volumeML: volumeML.flatMap { (10...5_000).contains($0) ? $0 : nil },
            rating: rating.flatMap { (1...5).contains($0) ? $0 : nil },
            season: logKind == .tv ? season.flatMap { (1...99).contains($0) ? $0 : nil } : nil,
            episodes: episodeNumbers,
            people: names.isEmpty ? nil : names
        )
    }

    /// The people named, trimmed and without repeats, in the order said. An `@dan` handle is Dan.
    var names: [String] {
        var seen = Set<String>()
        return (people ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.hasPrefix("@") ? Self.capitalisedHandle(String($0.dropFirst())) : $0 }
            .filter { !$0.isEmpty && $0.count <= 100 && seen.insert($0.lowercased()).inserted }
            .prefix(10)
            .map { $0 }
    }

    /// `dan` typed as a handle is the person Dan; a handle with capitals is kept as typed.
    private static func capitalisedHandle(_ handle: String) -> String {
        handle.contains(where: \.isUppercase) ? handle : handle.prefix(1).uppercased() + handle.dropFirst()
    }

    /// When it happened: the words the user used if they can be read, otherwise the minutes the model counted.
    /// Anything within two minutes of now is just now.
    private func occurredAt(now: Date) -> Date? {
        let resolved = when.flatMap { LogWhenParser.date(from: $0, now: now) }
            ?? minutesAgo.flatMap { $0 > 0 ? now.addingTimeInterval(-Double($0) * 60) : nil }
        guard let resolved, now.timeIntervalSince(resolved) > 120 else { return nil }
        return resolved
    }
}

private extension LogKind {
    /// The model writes the kind as free text: "boardGame", "board game" and "board_game" all mean the same.
    init?(modelValue: String) {
        let key = modelValue.lowercased().filter(\.isLetter)
        guard let kind = Self.allCases.first(where: { $0.rawValue.filter(\.isLetter) == key }) else { return nil }
        self = kind
    }
}

private extension LogServing {
    init?(modelValue: String) {
        self.init(rawValue: modelValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
