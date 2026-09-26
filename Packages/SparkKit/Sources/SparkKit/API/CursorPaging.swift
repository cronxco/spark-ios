import Foundation

/// A collection response in the mobile API's shared cursor envelope:
///
/// ```json
/// { "data": [...], "next_cursor": "…", "has_more": true }
/// ```
///
/// Every collection endpoint is paged, including ones whose lists are short
/// today, so a caller that wants the whole list follows the cursor rather
/// than trusting the first page to be all of it.
public protocol CursorPaged: Decodable, Sendable {
    associatedtype Item: Sendable
    var data: [Item] { get }
    var nextCursor: String? { get }
    var hasMore: Bool { get }
}

public extension APIClient {
    /// Follows `next_cursor` until the server says there is no more.
    ///
    /// Bounded by `maxPages`, and stops if the server hands back a cursor it
    /// has already given — either would otherwise loop forever against a
    /// misbehaving backend, on a phone, possibly inside a 25-second background
    /// budget.
    ///
    /// `endpoint` is `@Sendable` because it runs on this actor while the
    /// caller — usually a `@MainActor` view model — awaits. Build it from
    /// values, not from the caller's isolated state.
    func collectAllPages<Page: CursorPaged>(
        maxPages: Int = 20,
        _ endpoint: @Sendable (_ cursor: String?) -> Endpoint<Page>
    ) async throws -> [Page.Item] {
        var items: [Page.Item] = []
        var cursor: String?
        var seen: Set<String> = []

        for _ in 0..<maxPages {
            let page = try await request(endpoint(cursor))
            items.append(contentsOf: page.data)

            guard page.hasMore, let next = page.nextCursor, !seen.contains(next) else { break }
            seen.insert(next)
            cursor = next
        }
        return items
    }
}
