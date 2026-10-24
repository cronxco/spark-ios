import Foundation

/// One resolved CMD entry, ready to send. `id` doubles as the idempotency key.
public struct CmdEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let intent: CmdIntent
    public let text: String
    public let createdAt: Date
    /// What the classifier chose, kept so overrides can be measured.
    public let classifiedAs: CmdIntent?

    public init(id: UUID = UUID(), intent: CmdIntent, text: String, createdAt: Date = Date(), classifiedAs: CmdIntent?) {
        self.id = id
        self.intent = intent
        self.text = text
        self.createdAt = createdAt
        self.classifiedAs = classifiedAs
    }

    public var wasOverridden: Bool { classifiedAs != nil && classifiedAs != intent }
}

public enum CmdSubmissionResult: Equatable, Sendable {
    /// Written. `undoToken` is set when the write can be undone.
    case done(summary: String, undoToken: String?)
    /// Recoverable failure (offline, 5xx): keep it in the queue.
    case retry
    /// The server will not take it: drop it and say why.
    case rejected(reason: String)
}

/// Contract with the backend. WS1 (action registry), WS3 (quick log) and
/// WS6 (search) replace `StubCmdSubmitter` with the real calls.
public protocol CmdSubmitting: Sendable {
    func submit(_ entry: CmdEntry) async -> CmdSubmissionResult
    func undo(token: String) async -> Bool
}

/// Placeholder until the real endpoints land. Accepts everything.
public struct StubCmdSubmitter: CmdSubmitting {
    public init() {}

    public func submit(_ entry: CmdEntry) async -> CmdSubmissionResult {
        switch entry.intent {
        case .log: .done(summary: "Logged", undoToken: entry.id.uuidString)
        case .flintNote: .done(summary: "Noted for Flint", undoToken: entry.id.uuidString)
        case .command: .done(summary: "Done", undoToken: nil)
        case .search: .done(summary: "", undoToken: nil)
        }
    }

    public func undo(token: String) async -> Bool { true }
}

/// Entries that could not be sent yet, kept on this device and retried in
/// order. Survives relaunch; sign-out removes it.
/// `UserDefaults` is thread-safe, so the queue can cross actors.
public struct CmdQueue: @unchecked Sendable {
    public static let defaultsKey = "spark.cmd.queue"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> [CmdEntry] {
        guard let data = defaults.data(forKey: Self.defaultsKey) else { return [] }
        return (try? JSONDecoder().decode([CmdEntry].self, from: data)) ?? []
    }

    public func enqueue(_ entry: CmdEntry) {
        var entries = load()
        guard !entries.contains(where: { $0.id == entry.id }) else { return }
        entries.append(entry)
        save(entries)
    }

    public func remove(id: UUID) {
        save(load().filter { $0.id != id })
    }

    public func clear() {
        defaults.removeObject(forKey: Self.defaultsKey)
    }

    /// Sends queued entries oldest first and stops at the first retry so
    /// order is kept. Returns the entries that went through.
    @discardableResult
    public func flush(using submitter: any CmdSubmitting) async -> [(CmdEntry, CmdSubmissionResult)] {
        var sent: [(CmdEntry, CmdSubmissionResult)] = []
        for entry in load() {
            let result = await submitter.submit(entry)
            if result == .retry { break }
            remove(id: entry.id)
            sent.append((entry, result))
        }
        return sent
    }

    private func save(_ entries: [CmdEntry]) {
        guard !entries.isEmpty, let data = try? JSONEncoder().encode(entries) else {
            defaults.removeObject(forKey: Self.defaultsKey)
            return
        }
        defaults.set(data, forKey: Self.defaultsKey)
    }
}

/// Recent CMD entries for the empty state. Local only; stores the text and
/// intent so a tap can resend or reopen, never sent anywhere.
public struct CmdRecentStore {
    public static let defaultsKey = "spark.cmd.recents"
    public static let maxCount = 8
    public static let maxAge: TimeInterval = 30 * 24 * 60 * 60

    public struct Item: Codable, Equatable, Sendable {
        public let text: String
        public let intent: CmdIntent
        public let at: Date

        public init(text: String, intent: CmdIntent, at: Date) {
            self.text = text
            self.intent = intent
            self.at = at
        }
    }

    private let defaults: UserDefaults
    private let now: () -> Date

    public init(defaults: UserDefaults = .standard, now: @escaping () -> Date = { Date() }) {
        self.defaults = defaults
        self.now = now
    }

    public func load() -> [Item] {
        guard let data = defaults.data(forKey: Self.defaultsKey),
            let items = try? JSONDecoder().decode([Item].self, from: data)
        else { return [] }
        let cutoff = now().addingTimeInterval(-Self.maxAge)
        return items.filter { $0.at > cutoff }
    }

    @discardableResult
    public func record(text: String, intent: CmdIntent) -> [Item] {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var items = load()
        guard !clean.isEmpty else { return items }
        items.removeAll { $0.text == clean && $0.intent == intent }
        items.insert(Item(text: clean, intent: intent, at: now()), at: 0)
        items = Array(items.prefix(Self.maxCount))
        if let data = try? JSONEncoder().encode(items) { defaults.set(data, forKey: Self.defaultsKey) }
        return items
    }

    public func clear() {
        defaults.removeObject(forKey: Self.defaultsKey)
    }
}
