import Foundation
import SparkKit
import Testing

@testable import Spark

@Suite("Flint search")
struct FlintSearchTests {
    private func decode(_ json: String) throws -> SearchResult {
        try JSONDecoder().decode(SearchResult.self, from: Data(json.utf8))
    }

    @Test("a hit with a subtitle reads as title and subtitle")
    func lineWithSubtitle() throws {
        let hit = try decode(#"{"kind":"event","id":"e1","title":"Starbucks","subtitle":"£3.40"}"#)
        #expect(FlintSearch.line(for: hit) == "- Starbucks: £3.40")
    }

    @Test("a hit without a subtitle reads as the title alone")
    func lineWithoutSubtitle() throws {
        let hit = try decode(#"{"kind":"event","id":"e1","title":"Starbucks"}"#)
        #expect(FlintSearch.line(for: hit) == "- Starbucks")
    }

    @Test("events and objects are event-like, blocks are not")
    func classification() throws {
        let event = try decode(#"{"kind":"event","id":"e1","title":"Run"}"#)
        let object = try decode(#"{"kind":"object","id":"o1","title":"Gym"}"#)
        let block = try decode(#"{"kind":"block","id":"b1","title":"Note","block_type":"text"}"#)
        #expect(FlintSearch.isEventLike(event))
        #expect(FlintSearch.isEventLike(object))
        #expect(!FlintSearch.isEventLike(block))
        #expect(FlintSearch.isBlock(block))
        #expect(!FlintSearch.isBlock(event))
    }
}
