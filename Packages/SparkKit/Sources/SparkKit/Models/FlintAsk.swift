import Foundation

// Ask Flint: a conversation with the server-side Flint agent, which can
// search Spark and change it. Mirrors `POST /flint/ask` and the
// `/flint/ask/conversations` endpoints (contract version 2).

/// A record an answer links to, checked server-side against the user's data.
public struct FlintAskReference: Codable, Equatable, Sendable, Identifiable {
    /// `event`, `object` or `block`.
    public let kind: String
    public let id: String
    public let title: String

    public init(kind: String, id: String, title: String) {
        self.kind = kind
        self.id = id
        self.title = title
    }

    public var deepLink: DeepLink? {
        switch kind {
        case "event": .event(id: id)
        case "object": .object(id: id)
        case "block": .block(id: id)
        default: nil
        }
    }
}

/// One change Flint made. It was applied at once; `receiptId` undoes it
/// through the action receipts endpoint while `undo.available` holds.
public struct FlintAskChange: Codable, Equatable, Sendable, Identifiable {
    public struct Undo: Codable, Equatable, Sendable {
        public let available: Bool
        public let expiresAt: Date?
        public let undone: Bool

        public init(available: Bool, expiresAt: Date? = nil, undone: Bool = false) {
            self.available = available
            self.expiresAt = expiresAt
            self.undone = undone
        }

        enum CodingKeys: String, CodingKey {
            case available, undone
            case expiresAt = "expires_at"
        }
    }

    public let receiptId: String?
    /// `update`, `note`, `tag`, `link` or `delete`.
    public let operation: String
    /// `event`, `object` or `block`.
    public let kind: String
    public let entityId: String
    public let title: String
    public let summary: String
    public let undo: Undo

    public var id: String { receiptId ?? "\(operation):\(entityId)" }

    public init(
        receiptId: String?, operation: String, kind: String, entityId: String,
        title: String, summary: String, undo: Undo
    ) {
        self.receiptId = receiptId
        self.operation = operation
        self.kind = kind
        self.entityId = entityId
        self.title = title
        self.summary = summary
        self.undo = undo
    }

    enum CodingKeys: String, CodingKey {
        case operation, kind, title, summary, undo
        case receiptId = "receipt_id"
        case entityId = "id"
    }

    /// Whether an Undo can still be offered at `now`. The server's flag is a
    /// snapshot, so the expiry is checked again on the device.
    public func canUndo(at now: Date = .now) -> Bool {
        guard receiptId != nil, undo.available, !undo.undone else { return false }
        guard let expiresAt = undo.expiresAt else { return true }
        return expiresAt > now
    }

    /// The same change after its Undo has run.
    public func markedUndone() -> FlintAskChange {
        FlintAskChange(
            receiptId: receiptId, operation: operation, kind: kind, entityId: entityId,
            title: title, summary: summary,
            undo: Undo(available: false, expiresAt: undo.expiresAt, undone: true)
        )
    }
}

/// One thing Flint did on the way to an answer, in the reader's words: a
/// tool it used ("Searched events for “flight”"), with what it covered, what
/// it found and the records it found, or a short summary of its reasoning.
public struct FlintAskStep: Codable, Equatable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable {
        case tool
        case reasoning
    }

    public enum Status: String, Codable, Sendable {
        case running
        case done
        case failed
    }

    public let id: String
    public let kind: Kind
    /// The tool's name, for a tool step.
    public let tool: String?
    /// A Font Awesome name from the server ("magnifying-glass").
    public let glyph: String?
    public let label: String
    /// What a tool covered ("Sun 22 to Sat 28 Nov"), or a reasoning summary.
    public var detail: String?
    public var status: Status
    /// What a tool found ("3 matches").
    public var result: String?
    public var records: [FlintAskReference]
    public var durationMs: Int?

    public init(
        id: String, kind: Kind = .tool, tool: String? = nil, glyph: String? = nil, label: String,
        detail: String? = nil, status: Status = .done, result: String? = nil,
        records: [FlintAskReference] = [], durationMs: Int? = nil
    ) {
        self.id = id
        self.kind = kind
        self.tool = tool
        self.glyph = glyph
        self.label = label
        self.detail = detail
        self.status = status
        self.result = result
        self.records = records
        self.durationMs = durationMs
    }

    /// A reasoning step as its summary starts to arrive.
    public static func reasoning(id: String, text: String) -> FlintAskStep {
        FlintAskStep(id: id, kind: .reasoning, glyph: "lightbulb", label: "Thought it through", detail: text)
    }

    enum CodingKeys: String, CodingKey {
        case id, tool, glyph, label, detail, status, result, records
        case kind = "type"
        case durationMs = "duration_ms"
    }

    /// Unknown kinds and statuses from a newer server read as a finished tool step.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = (try? container.decodeIfPresent(Kind.self, forKey: .kind)) ?? .tool
        tool = try container.decodeIfPresent(String.self, forKey: .tool)
        glyph = try container.decodeIfPresent(String.self, forKey: .glyph)
        label = try container.decode(String.self, forKey: .label)
        detail = try container.decodeIfPresent(String.self, forKey: .detail)
        status = (try? container.decodeIfPresent(Status.self, forKey: .status)) ?? .done
        result = try container.decodeIfPresent(String.self, forKey: .result)
        records = (try? container.decodeIfPresent([FlintAskReference].self, forKey: .records)) ?? []
        durationMs = try container.decodeIfPresent(Int.self, forKey: .durationMs)
    }
}

public struct FlintAskMessage: Codable, Equatable, Sendable {
    public enum Role: String, Codable, Sendable {
        case user
        case assistant
    }

    /// Nil only for a turn the server could not store.
    public let id: String?
    public let role: Role
    /// Markdown. Records are linked by path: `/events/{id}`.
    public let text: String
    public let references: [FlintAskReference]
    public let changes: [FlintAskChange]
    /// What Flint did to answer, in order. Empty on a user's message.
    public let steps: [FlintAskStep]
    /// Cards for the events the answer links, in the order it first links them.
    public let cards: [LinkedEventCard]
    /// Up to two questions Flint suggests asking next.
    public let followUps: [String]
    /// How long the answer took, when it was timed.
    public let elapsedMs: Int?
    /// `completed`, `failed` or `paused`.
    public let status: String
    public let createdAt: Date?

    public init(
        id: String?, role: Role, text: String, references: [FlintAskReference] = [],
        changes: [FlintAskChange] = [], steps: [FlintAskStep] = [], cards: [LinkedEventCard] = [],
        followUps: [String] = [], elapsedMs: Int? = nil, status: String = "completed", createdAt: Date? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.references = references
        self.changes = changes
        self.steps = steps
        self.cards = cards
        self.followUps = followUps
        self.elapsedMs = elapsedMs
        self.status = status
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, role, text, references, changes, steps, cards, status
        case followUps = "follow_ups"
        case elapsedMs = "elapsed_ms"
        case createdAt = "created_at"
    }

    /// Contract 1 messages have no steps, cards or follow-ups. One malformed
    /// step or card is dropped rather than failing the message.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        role = try container.decode(Role.self, forKey: .role)
        text = try container.decode(String.self, forKey: .text)
        references = try container.decodeIfPresent([FlintAskReference].self, forKey: .references) ?? []
        changes = try container.decodeIfPresent([FlintAskChange].self, forKey: .changes) ?? []
        steps = (try? container.decodeIfPresent([FlintAskLossy<FlintAskStep>].self, forKey: .steps))?
            .compactMap(\.value) ?? []
        cards = (try? container.decodeIfPresent([FlintAskLossy<LinkedEventCard>].self, forKey: .cards))?
            .compactMap(\.value) ?? []
        followUps = (try? container.decodeIfPresent([String].self, forKey: .followUps)) ?? []
        elapsedMs = try? container.decodeIfPresent(Int.self, forKey: .elapsedMs)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "completed"
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
    }
}

/// One element of an array, or nothing, so a bad element doesn't fail the rest.
private struct FlintAskLossy<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: Decoder) throws {
        value = try? Value(from: decoder)
    }
}

/// The finished answer to one question.
public struct FlintAskAnswer: Codable, Equatable, Sendable {
    public let conversationId: String?
    public let message: FlintAskMessage

    public init(conversationId: String?, message: FlintAskMessage) {
        self.conversationId = conversationId
        self.message = message
    }

    enum CodingKeys: String, CodingKey {
        case message
        case conversationId = "conversation_id"
    }
}

public struct FlintAskConversation: Codable, Equatable, Sendable, Identifiable, Hashable {
    public let id: String
    public let title: String
    public let createdAt: Date?
    public let updatedAt: Date?
    /// The latest answer's opening sentence or two, as plain text.
    public let preview: String?
    /// The domains of the records the latest answer linked: `health`,
    /// `money` and so on. Empty for a conversation that linked nothing.
    public let domains: [String]
    /// How many changes Flint made in the conversation.
    public let changeCount: Int

    public init(
        id: String, title: String, createdAt: Date? = nil, updatedAt: Date? = nil,
        preview: String? = nil, domains: [String] = [], changeCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.preview = preview
        self.domains = domains
        self.changeCount = changeCount
    }

    enum CodingKeys: String, CodingKey {
        case id, title, preview, domains
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case changeCount = "change_count"
    }

    /// Contract 1 servers send only the id, title and dates.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        preview = try container.decodeIfPresent(String.self, forKey: .preview)
        domains = try container.decodeIfPresent([String].self, forKey: .domains) ?? []
        changeCount = try container.decodeIfPresent(Int.self, forKey: .changeCount) ?? 0
    }
}

public struct FlintAskConversationsPage: Codable, Equatable, Sendable {
    public let data: [FlintAskConversation]
    public let nextCursor: String?
    public let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case data
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}

/// A page of one conversation, oldest message first. The cursor pages back
/// towards the start of the thread.
public struct FlintAskMessagesPage: Codable, Equatable, Sendable {
    public let data: [FlintAskMessage]
    public let nextCursor: String?
    public let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case data
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}

/// One frame of a streamed answer.
public enum FlintAskStreamEvent: Equatable, Sendable {
    /// The thread has an id; sent once, before any text.
    case conversation(id: String)
    /// The next piece of the answer.
    case delta(String)
    /// Flint started using a tool; `label` is what to show ("Searching Spark").
    case activity(label: String)
    /// A step started (`running`) or finished. The same id arrives twice.
    case step(FlintAskStep)
    /// The next piece of a reasoning summary, for the reasoning step `id`.
    case reasoning(id: String, text: String)
    /// A change was applied.
    case change(FlintAskChange)
    /// The finished message. Its text replaces the accumulated deltas.
    case done(FlintAskAnswer)
    /// The turn failed after the stream had started.
    case failed(message: String)

    /// Decodes a server-sent event. Returns nil for an event this build does
    /// not know, so a newer server can add frames without breaking the app.
    public static func decode(_ event: ServerSentEvent) -> FlintAskStreamEvent? {
        guard let data = event.data.data(using: .utf8) else { return nil }
        let decoder = FlintAskCoding.decoder

        switch event.name {
        case "conversation":
            return (try? decoder.decode(ConversationFrame.self, from: data)).map { .conversation(id: $0.conversationId) }
        case "delta":
            return (try? decoder.decode(DeltaFrame.self, from: data)).map { .delta($0.text) }
        case "activity":
            return (try? decoder.decode(ActivityFrame.self, from: data)).map { .activity(label: $0.label) }
        case "change":
            return (try? decoder.decode(FlintAskChange.self, from: data)).map { .change($0) }
        case "step":
            return (try? decoder.decode(FlintAskStep.self, from: data)).map { .step($0) }
        case "reasoning":
            return (try? decoder.decode(ReasoningFrame.self, from: data)).map { .reasoning(id: $0.id, text: $0.text) }
        case "done":
            return (try? decoder.decode(FlintAskAnswer.self, from: data)).map { .done($0) }
        case "error":
            return (try? decoder.decode(ErrorFrame.self, from: data)).map { .failed(message: $0.message) }
        default:
            return nil
        }
    }

    private struct ConversationFrame: Decodable {
        let conversationId: String
        enum CodingKeys: String, CodingKey { case conversationId = "conversation_id" }
    }

    private struct DeltaFrame: Decodable { let text: String }
    private struct ActivityFrame: Decodable { let label: String }
    private struct ErrorFrame: Decodable { let message: String }
    private struct ReasoningFrame: Decodable { let id: String; let text: String }
}

enum FlintAskCoding {
    /// Stream frames are decoded outside `APIClient`, so they carry their own
    /// decoder. The server writes ISO 8601 with an offset and no fraction.
    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

public enum FlintAskText {
    /// Makes an answer's record links absolute (`/events/{id}` →
    /// `https://spark.cronx.co/events/{id}`) so they parse as deep links and
    /// route through the host view's `openURL` action.
    public static func linkified(_ markdown: String, host: String = "spark.cronx.co") -> String {
        var result = markdown
        for path in ["events", "objects", "blocks"] {
            result = result.replacingOccurrences(of: "](/\(path)/", with: "](https://\(host)/\(path)/")
        }
        return result
    }

    /// An answer as it should be spoken or shown where Markdown is not
    /// rendered: link targets and emphasis marks removed, lists flattened,
    /// and cut at a sentence boundary when it runs past `limit` characters.
    public static func spoken(_ markdown: String, limit: Int = 480) -> String {
        var text = markdown
        let rewrites: [(pattern: String, template: String)] = [
            (#"\[([^\]]+)\]\([^)]*\)"#, "$1"),
            (#"(?m)^\s{0,3}#{1,6}\s+"#, ""),
            (#"(?m)^\s*[-*•]\s+"#, ""),
            (#"(?m)^\s*\d+\.\s+"#, ""),
            (#"[*_`]{1,3}"#, ""),
            (#"\s*\n+\s*"#, " "),
            (#" {2,}"#, " "),
        ]
        for rewrite in rewrites {
            text = text.replacingOccurrences(of: rewrite.pattern, with: rewrite.template, options: .regularExpression)
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard text.count > limit else { return text }

        let head = String(text.prefix(limit))
        if let end = head.lastIndex(where: { ".!?".contains($0) }), head.distance(from: head.startIndex, to: end) > limit / 3 {
            return String(head[...end])
        }
        return head.trimmingCharacters(in: .whitespaces) + "…"
    }
}
