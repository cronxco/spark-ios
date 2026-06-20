import Foundation
import Testing
@testable import SparkKit

@Suite("Tags API")
struct TagsEndpointTests {
    @Test("decodes browse and detail payloads")
    func decodesPayloads() throws {
        let browseJSON = """
        {
          "data": [{
            "id": "tag-1",
            "name": "coffee",
            "type": "spark",
            "events_count": 2,
            "objects_count": 1,
            "total_count": 3
          }],
          "next_cursor": "next",
          "has_more": true
        }
        """

        let browse = try JSONDecoder().decode(Page<SparkKit.Tag>.self, from: Data(browseJSON.utf8))
        #expect(browse.data.first?.id == "tag-1")
        #expect(browse.data.first?.totalCount == 3)
        #expect(browse.nextCursor == "next")

        let detailJSON = """
        {
          "tag": {
            "id": "tag-1",
            "name": "coffee",
            "type": "spark",
            "events_count": 1,
            "objects_count": 0,
            "total_count": 1
          },
          "data": [{
            "kind": "event",
            "id": "event-1",
            "title": "Coffee",
            "subtitle": "Today",
            "domain": "money"
          }],
          "next_cursor": null,
          "has_more": false
        }
        """

        let detail = try JSONDecoder().decode(TagDetailPage.self, from: Data(detailJSON.utf8))
        #expect(detail.tag.name == "coffee")
        #expect(detail.data.count == 1)
    }

    @Test("builds mutation endpoints")
    func mutationEndpoints() {
        let add = TagsEndpoint.add(entity: .event, id: "event-1", tagID: "tag-1")
        #expect(add.method == .post)
        #expect(add.path == "/events/event-1/tags")

        let remove = TagsEndpoint.remove(entity: .object, id: "object-1", tagID: "tag-1")
        #expect(remove.method == .delete)
        #expect(remove.path == "/objects/object-1/tags/tag-1")
    }

    @Test("event tags decode stable server IDs and legacy strings")
    func eventTagCompatibility() throws {
        let tagged = try JSONDecoder().decode(
            EventTag.self,
            from: Data(#"{"id":"tag-1","name":"coffee","type":"spark"}"#.utf8)
        )
        #expect(tagged.id == "tag-1")

        let legacy = try JSONDecoder().decode(EventTag.self, from: Data(#""coffee""#.utf8))
        #expect(legacy.serverID == nil)
        #expect(legacy.name == "coffee")
    }
}
