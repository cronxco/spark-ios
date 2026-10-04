import Foundation
import Testing
@testable import SparkKit

/// EOB-D5: soft delete with Undo for events and objects.
@Suite("Entity delete and restore")
struct EntityDeleteRestoreTests {
    @Test("deleting an event sends its current version")
    func eventDeleteSendsIfMatch() {
        let endpoint = EventsEndpoint.delete(id: "evt_1", etag: "\"v4\"")
        #expect(endpoint.method == .delete)
        #expect(endpoint.path == "/events/evt_1")
        #expect(endpoint.headers["If-Match"] == "\"v4\"")
    }

    @Test("deleting an object sends its current version")
    func objectDeleteSendsIfMatch() {
        let endpoint = ObjectsEndpoint.delete(id: "obj_1", etag: "\"v2\"")
        #expect(endpoint.method == .delete)
        #expect(endpoint.path == "/objects/obj_1")
        #expect(endpoint.headers["If-Match"] == "\"v2\"")
    }

    @Test("restore is a precondition-free POST, so Undo works after the version is gone")
    func restoreHasNoPrecondition() {
        let event = EventsEndpoint.restore(id: "evt_1")
        #expect(event.method == .post)
        #expect(event.path == "/events/evt_1/restore")
        #expect(event.headers["If-Match"] == nil)

        let object = ObjectsEndpoint.restore(id: "obj_1")
        #expect(object.method == .post)
        #expect(object.path == "/objects/obj_1/restore")
        #expect(object.headers["If-Match"] == nil)
    }

    @Test("the delete body decodes")
    func deletedEntityDecodes() throws {
        let deleted = try JSONDecoder().decode(DeletedEntity.self, from: Data("""
        {"id":"evt_1","deleted_at":"2026-10-04T09:30:00+01:00"}
        """.utf8))
        #expect(deleted.id == "evt_1")
        #expect(deleted.deletedAt == "2026-10-04T09:30:00+01:00")
    }

    @Test("a restored object without recent events still decodes")
    func restoredObjectDecodes() throws {
        let detail = try JSONDecoder().decode(ObjectDetail.self, from: Data("""
        {"id":"obj_1","concept":"place","type":"cafe","title":"Corner Cafe","tags":[]}
        """.utf8))
        #expect(detail.object.title == "Corner Cafe")
        #expect(detail.recentEvents.isEmpty)
    }
}
