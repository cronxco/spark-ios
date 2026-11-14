import Foundation

/// One server-sent event: its `event:` name and its `data:` payload.
public struct ServerSentEvent: Equatable, Sendable {
    public let name: String
    public let data: String

    public init(name: String, data: String) {
        self.name = name
        self.data = data
    }
}

/// Assembles server-sent events from the lines of a response body.
///
/// An event is emitted as soon as its `data:` line arrives rather than at the
/// blank line that ends it: `URLSession.AsyncBytes.lines` drops empty lines,
/// so the terminator can't be relied on. That holds for Spark's streams,
/// which send one `event:` line and one single-line JSON `data:` line per
/// event; multi-line `data:` payloads are not supported.
public struct ServerSentEventParser: Sendable {
    private var pendingName: String?

    public init() {}

    /// Feeds one line (without its line ending). Returns an event when the
    /// line completes one.
    public mutating func consume(_ line: String) -> ServerSentEvent? {
        if line.isEmpty {
            pendingName = nil
            return nil
        }
        // A line starting with a colon is a comment, used as a keep-alive.
        if line.hasPrefix(":") { return nil }

        let field: Substring
        var value: Substring
        if let colon = line.firstIndex(of: ":") {
            field = line[..<colon]
            value = line[line.index(after: colon)...]
            if value.hasPrefix(" ") { value = value.dropFirst() }
        } else {
            field = Substring(line)
            value = ""
        }

        switch field {
        case "event":
            pendingName = String(value)
            return nil
        case "data":
            defer { pendingName = nil }
            return ServerSentEvent(name: pendingName ?? "message", data: String(value))
        default:
            return nil
        }
    }
}
