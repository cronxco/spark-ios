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

    public static func digest(id: String) -> Endpoint<FlintDigest> {
        Endpoint(method: .get, path: "/flint/digests/\(id)")
    }

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
