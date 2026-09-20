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
}
