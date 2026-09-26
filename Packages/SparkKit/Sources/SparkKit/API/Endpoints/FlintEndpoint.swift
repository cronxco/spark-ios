import Foundation

public enum FlintEndpoint {
    public static func digests(
        date: String? = nil,
        period: FlintDigestPeriod? = nil,
        all: Bool = true
    ) -> Endpoint<FlintDigestListResponse> {
        Endpoint(method: .get, path: "/flint/digests", query: digestQuery(date: date, period: period, all: all))
    }

    public static func latestDigest(date: String? = nil, period: FlintDigestPeriod? = nil) -> Endpoint<FlintDigest> {
        Endpoint(method: .get, path: "/flint/digests", query: digestQuery(date: date, period: period, all: false))
    }

    /// GET /flint/digests/latest — the single most recent digest across
    /// dates. Before the morning brief has run that is last night's evening
    /// digest, which a date-scoped request cannot express. 404 when the user
    /// has no digest of that kind at all.
    public static func latest(kind: FlintDigestKind? = .briefing) -> Endpoint<FlintDigest> {
        var query: [URLQueryItem] = []
        if let kind {
            query.append(URLQueryItem(name: "kind", value: kind.rawValue))
        }
        return Endpoint(method: .get, path: "/flint/digests/latest", query: query)
    }

    public static func digest(id: String) -> Endpoint<FlintDigest> {
        Endpoint(method: .get, path: "/flint/digests/\(id)")
    }

    public static func history(
        from: String,
        to: String,
        limit: Int = 50,
        cursor: String? = nil
    ) -> Endpoint<FlintDigestHistoryResponse> {
        var query = [
            URLQueryItem(name: "from", value: from),
            URLQueryItem(name: "to", value: to),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        if let cursor {
            query.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return Endpoint(method: .get, path: "/flint/digests", query: query)
    }

    public static func questions(
        status: FlintQuestionStatus = .open,
        limit: Int = 50,
        cursor: String? = nil
    ) -> Endpoint<FlintQuestionsResponse> {
        var query = [
            URLQueryItem(name: "status", value: status.rawValue),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        if let cursor {
            query.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return Endpoint(method: .get, path: "/flint/questions", query: query)
    }

    /// GET /flint/questions?status=open,answered&since=48h
    ///
    /// Several statuses in one request, and a window applied server-side —
    /// `since` takes an ISO timestamp or a relative window such as `48h` or
    /// `7d`.
    public static func questions(
        statuses: [FlintQuestionStatus],
        since: String? = nil,
        limit: Int = 20,
        cursor: String? = nil
    ) -> Endpoint<FlintQuestionsResponse> {
        var query = [
            URLQueryItem(name: "status", value: statuses.map(\.rawValue).joined(separator: ",")),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        if let since {
            query.append(URLQueryItem(name: "since", value: since))
        }
        if let cursor {
            query.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return Endpoint(method: .get, path: "/flint/questions", query: query)
    }

    public static func questionAction(
        blockID: String,
        version: String,
        idempotencyKey: UUID,
        _ request: FlintQuestionActionRequest
    ) -> Endpoint<FlintQuestionActionResponse> {
        Endpoint(
            method: .post,
            path: "/flint/questions/\(blockID)/actions",
            body: try? JSONEncoder().encode(request),
            contentType: "application/json",
            headers: [
                "If-Match": version,
                "Idempotency-Key": idempotencyKey.uuidString,
            ]
        )
    }

    /// Deprecated server-side (it now sends `Deprecation` and a `Sunset`):
    /// answer through `questionAction` instead, which carries `If-Match` and
    /// an idempotency key. Kept only while the remaining caller moves over.
    public static func answerQuestion(
        blockID: String,
        _ request: FlintQuestionAnswerRequest
    ) -> Endpoint<FlintQuestionAnswerResponse> {
        let body = try? JSONEncoder().encode(request)
        return Endpoint(
            method: .post,
            path: "/flint/questions/\(blockID)/answer",
            body: body,
            contentType: "application/json"
        )
    }

    public static func notes(limit: Int = 20, cursor: String? = nil) -> Endpoint<FlintNotesResponse> {
        var query = [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor {
            query.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return Endpoint(
            method: .get,
            path: "/flint/notes",
            query: query,
            headers: ["Cache-Control": "no-cache"]
        )
    }

    public static func createNote(_ request: FlintNoteCreateRequest) -> Endpoint<FlintNoteResponse> {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return Endpoint(
            method: .post,
            path: "/flint/notes",
            body: try? encoder.encode(request),
            contentType: "application/json"
        )
    }

    public static func deleteNote(id: String) -> Endpoint<EmptyResponse> {
        Endpoint(method: .delete, path: "/flint/notes/\(id)")
    }

    private static func digestQuery(
        date: String?,
        period: FlintDigestPeriod?,
        all: Bool
    ) -> [URLQueryItem] {
        var query: [URLQueryItem] = []
        if let date {
            query.append(URLQueryItem(name: "date", value: date))
        }
        if let period {
            query.append(URLQueryItem(name: "period", value: period.rawValue))
        }
        if all {
            query.append(URLQueryItem(name: "all", value: "true"))
        }
        return query
    }
}
