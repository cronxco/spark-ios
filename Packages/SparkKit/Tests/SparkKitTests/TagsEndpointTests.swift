import Foundation
import Testing
@testable import SparkKit

@Suite("Tags endpoints")
struct TagsEndpointTests {
    @Test("suggestions decode data wrapper with numeric IDs")
    func suggestionsDecode() throws {
        let page = try JSONDecoder().decode(TagPage.self, from: Data("""
        {"data":[{"id":42,"name":"coffee","type":"merchant","events_count":3,"objects_count":1}],"next_cursor":"next","has_more":true}
        """.utf8))
        #expect(page.data.first?.id == "42")
        #expect(page.nextCursor == "next")
        #expect(page.hasMore)
    }

    @Test("attach and detach include mutation path, body and ETag")
    func mutationEndpoints() throws {
        let attach: Endpoint<EventDetail> = TagsEndpoint.attach(
            kind: .events, id: "evt_1", request: TagMutationRequest(tagID: "tag_1"), etag: "\"v1\"", response: EventDetail.self
        )
        #expect(attach.method == .post)
        #expect(attach.path == "/events/evt_1/tags")
        #expect(attach.headers["If-Match"] == "\"v1\"")
        let body = try #require(attach.body)
        #expect(String(data: body, encoding: .utf8)?.contains("\"tag_id\":\"tag_1\"") == true)

        let detach: Endpoint<ObjectDetail> = TagsEndpoint.detach(
            kind: .objects, id: "obj_1", tagID: "tag_1", etag: "\"v2\"", response: ObjectDetail.self
        )
        #expect(detach.method == .delete)
        #expect(detach.path == "/objects/obj_1/tags/tag_1")
        #expect(detach.headers["If-Match"] == "\"v2\"")
    }
}
