import Foundation
import Testing
@testable import SparkKit

@Suite("Entity mutation contract")
struct EntityMutationContractTests {
    @Test("relationship create sends the singular kind the API validates")
    func createSendsSingularKind() throws {
        let endpoint = try EntityMutationsEndpoint.createRelationship(
            kind: .events, id: "evt_1", request: RelationshipCreateRequest(toKind: .objects, toID: "obj_1", type: "related_to"), etag: "\"v1\""
        )
        #expect(endpoint.path == "/events/evt_1/relationships")
        #expect(endpoint.headers["If-Match"] == "\"v1\"")
        let body = try #require(endpoint.body)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["to_kind"] as? String == "object")
    }

    @Test("every kind maps to its singular payload value")
    func payloadValues() {
        #expect(SparkEntityKind.allCases.map(\.payloadValue) == ["event", "object", "block"])
    }

    @Test("a create response carries the edge version and the refreshed parent version")
    func createResponseVersions() throws {
        let relationship = try JSONDecoder().decode(EntityRelationship.self, from: Data("""
        {"id":"rel_1","type":"related_to","from_type":"event","from_id":"evt_1","to_type":"object","to_id":"obj_1",
         "value":null,"value_unit":null,"metadata":null,"etag":"\\"edge\\"",
         "versions":[{"kind":"event","id":"evt_1","etag":"\\"evt-v2\\""},{"kind":"object","id":"obj_1","etag":"\\"obj-v2\\""}]}
        """.utf8))
        #expect(relationship.etag == "\"edge\"")
        #expect(relationship.versions?.etag(for: .events, id: "evt_1") == "\"evt-v2\"")
        #expect(relationship.versions?.etag(for: .objects, id: "evt_1") == nil)
    }

    @Test("a list row from an older server still decodes without versions")
    func listRowWithoutVersions() throws {
        let relationship = try JSONDecoder().decode(EntityRelationship.self, from: Data("""
        {"id":"rel_1","type":"part_of","from_type":"event","from_id":"evt_1","to_type":"block","to_id":"blk_1"}
        """.utf8))
        #expect(relationship.etag == nil)
        #expect(relationship.versions == nil)
    }

    @Test("relationship delete uses the edge's own version")
    func deleteUsesEdgeVersion() {
        let endpoint = EntityMutationsEndpoint.deleteRelationship(id: "rel_1", etag: "\"edge\"")
        #expect(endpoint.method == .delete)
        #expect(endpoint.path == "/relationships/rel_1")
        #expect(endpoint.headers["If-Match"] == "\"edge\"")
    }

    @Test("relationship types decode from the registry endpoint")
    func relationshipTypesDecode() throws {
        #expect(EntityMutationsEndpoint.relationshipTypes().path == "/relationship-types")
        let response = try JSONDecoder().decode(RelationshipTypesResponse.self, from: Data("""
        {"data":[{"type":"transferred_to","display_name":"Transferred To","description":"Money moved","is_directional":true,"supports_value":true,"default_value_unit":"GBP"}]}
        """.utf8))
        #expect(response.data.first?.displayName == "Transferred To")
        #expect(response.data.first?.supportsValue == true)
    }

    @Test("the re-read after a write skips the ETag cache")
    func detailForWriteSkipsCache() {
        let endpoint = EntityMutationsEndpoint.detailForWrite(kind: .objects, id: "obj_1", response: ObjectDetail.self)
        #expect(endpoint.path == "/objects/obj_1")
        #expect(endpoint.usesETag == false)
    }

    @Test("saving a note sends the event's current version")
    func noteSendsIfMatch() {
        let endpoint = EventsEndpoint.updateNote(id: "evt_1", note: "hello", etag: "\"v3\"")
        #expect(endpoint.method == .patch)
        #expect(endpoint.path == "/events/evt_1/note")
        #expect(endpoint.headers["If-Match"] == "\"v3\"")
    }
}
