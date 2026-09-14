#if DEBUG
import Foundation

/// Memory-only developer inspection. Independent of production telemetry.
/// Every mutation and snapshot is protected by `lock`; no lock spans an await.
public final class APISessionStore: @unchecked Sendable {
    public static let shared = APISessionStore()
    public struct Ticket: Sendable {
        public let id: UUID
        fileprivate let generation: UUID
    }
    public struct Entry: Identifiable, Sendable {
        public let id: UUID
        public let requestID: UUID
        public let attempt: Int
        public let startedAt: Date
        public let method: String
        public let path: String
        public var duration: TimeInterval = 0
        public var status: Int?
        public var outcome = "pending"
        public var body = Data()
        public var originalBytes = 0
        public var omitted = false
        public var truncated = false
        public var export: String {
            let label = omitted ? "<authentication body omitted>" : body.isEmpty ? "<empty response>" : String(decoding: body, as: UTF8.self)
            return """
            \(method) \(path)
            Attempt ID: \(id) | Request ID: \(requestID) | Attempt: \(attempt)
            Started: \(startedAt.ISO8601Format()) | Duration: \(duration)s
            Status: \(status.map(String.init) ?? "none") | Outcome: \(outcome)
            Response bytes: \(originalBytes)\(truncated ? " | TRUNCATED capture" : "")
            \(label)
            """
        }
    }
    public struct Snapshot: Sendable {
        public let entries: [Entry]
        public let evicted: Int
        public var export: String {
            "API session — \(evicted) attempts evicted by retention limits\n\n" + entries.map(\.export).joined(separator: "\n\n")
        }
    }
    private let lock = NSLock()
    private var generation = UUID()
    private var entries: [Entry] = []
    private var evicted = 0
    private let maxAttempts: Int
    private let maxBytes: Int
    private let bodyLimit: Int

    public init(maxAttempts: Int = 200, maxBytes: Int = 20 * 1024 * 1024, bodyLimit: Int = 2 * 1024 * 1024) {
        self.maxAttempts = max(1, maxAttempts)
        self.maxBytes = max(0, maxBytes)
        self.bodyLimit = max(0, bodyLimit)
    }
    public func begin(_ request: URLRequest, requestID: UUID = UUID(), attempt: Int = 1) -> Ticket {
        lock.withLock {
            let id = UUID()
            let url = request.url.map(APITelemetryRedactor.url)
            let path = (url?.path ?? "<invalid URL>") + (url?.query.map { "?" + $0 } ?? "")
            entries.insert(Entry(id: id, requestID: requestID, attempt: attempt, startedAt: Date(), method: request.httpMethod ?? "GET", path: path), at: 0)
            trim()
            return Ticket(id: id, generation: generation)
        }
    }
    /// Called as bytes arrive, before any application decoder runs.
    public func response(_ ticket: Ticket, status: Int?, data: Data, append: Bool = false) {
        lock.withLock {
            guard ticket.generation == generation, let index = entries.firstIndex(where: { $0.id == ticket.id }) else { return }
            entries[index].status = status
            let sensitive = entries[index].path.contains("/oauth/") || entries[index].path.contains("/broadcasting/auth")
            entries[index].omitted = sensitive
            entries[index].originalBytes = (append ? entries[index].originalBytes : 0) + data.count
            if !sensitive {
                if !append { entries[index].body = Data() }
                let available = max(0, min(bodyLimit, maxBytes) - entries[index].body.count)
                entries[index].body.append(data.prefix(available))
                entries[index].truncated = entries[index].originalBytes > entries[index].body.count
            }
            trim()
        }
    }
    public func finish(_ ticket: Ticket, outcome: String, status: Int? = nil) {
        lock.withLock {
            guard ticket.generation == generation, let index = entries.firstIndex(where: { $0.id == ticket.id }) else { return }
            entries[index].outcome = outcome
            if let status { entries[index].status = status }
            entries[index].duration = Date().timeIntervalSince(entries[index].startedAt)
        }
    }
    public func clear() {
        lock.withLock { generation = UUID(); entries.removeAll(); evicted = 0 }
    }
    public func snapshot() -> Snapshot {
        lock.withLock { Snapshot(entries: entries, evicted: evicted) }
    }
    private func trim() {
        var bytes = entries.reduce(0) { $0 + $1.body.count }
        while entries.count > maxAttempts || bytes > maxBytes {
            bytes -= entries.removeLast().body.count
            evicted += 1
        }
    }
}
#endif
