import Foundation
import Testing
@testable import SparkKit

@Suite("FlintTopics endpoints")
struct FlintTopicsEndpointTests {
    @Test("list endpoint with no filters")
    func listEndpointNoFilters() {
        let endpoint = FlintTopicsEndpoint.list()

        #expect(endpoint.method == .get)
        #expect(endpoint.path == "/flint/topics")
        #expect(endpoint.query.isEmpty)
    }

    @Test("list endpoint carries status and kind filters")
    func listEndpointWithFilters() {
        let endpoint = FlintTopicsEndpoint.list(status: .dormant, kind: .thematic)

        #expect(endpoint.method == .get)
        #expect(endpoint.path == "/flint/topics")
        #expect(endpoint.query.first { $0.name == "status" }?.value == "dormant")
        #expect(endpoint.query.first { $0.name == "kind" }?.value == "thematic")
    }

    @Test("detail endpoint addresses one topic")
    func detailEndpoint() {
        let endpoint = FlintTopicsEndpoint.detail(id: "topic-1")

        #expect(endpoint.method == .get)
        #expect(endpoint.path == "/flint/topics/topic-1")
        #expect(endpoint.query.isEmpty)
    }

    @Test("type edit and task mutations carry the thread version")
    func mutations() throws {
        let edit = FlintTopicsEndpoint.changeKind(id: "topic-1", kind: .thematic, etag: "\"v1\"")
        #expect(edit.method == .patch)
        #expect(edit.headers["If-Match"] == "\"v1\"")
        #expect(String(decoding: try #require(edit.body), as: UTF8.self).contains("thematic"))

        let request = FlintTopicTaskRequest(
            clientMutationID: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!,
            title: "Book Vancouver night", dueOn: "2027-08-01", reviewOn: "2027-07-15"
        )
        let create = FlintTopicsEndpoint.createTask(id: "topic-1", request: request, etag: "\"v1\"")
        #expect(create.method == .post)
        #expect(create.headers["If-Match"] == "\"v1\"")
        let body = try JSONSerialization.jsonObject(with: #require(create.body)) as? [String: String]
        #expect(body?["due_on"] == "2027-08-01")
        #expect(body?["review_on"] == "2027-07-15")
        #expect(body?["client_mutation_id"] == "11111111-1111-4111-8111-111111111111")
    }
}
