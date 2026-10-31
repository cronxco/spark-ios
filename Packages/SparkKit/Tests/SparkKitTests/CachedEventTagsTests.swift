import Foundation
import Testing

@testable import SparkKit

@Suite("Cached event tags")
struct CachedEventTagsTests {
    private func event(tagNames: String?) -> CachedEvent {
        CachedEvent(id: "e1", time: nil, service: "spotify", domain: "media", action: "listened_to", tagNames: tagNames)
    }

    @Test("a tag's type survives the cache")
    func typesRoundTrip() {
        let tags = [
            EventTag(name: "Radiohead", type: "spotify_artist"),
            EventTag(name: "Focus"),
        ]
        let decoded = event(tagNames: CachedEvent.encodeTagNames(tags)).decodedTags
        #expect(decoded.map(\.name) == ["Radiohead", "Focus"])
        #expect(decoded.map(\.type) == ["spotify_artist", nil])
    }

    @Test("rows cached before types were kept read as untyped tags")
    func legacyNamesOnly() {
        let decoded = event(tagNames: "Radiohead\u{1F}Focus").decodedTags
        #expect(decoded.map(\.name) == ["Radiohead", "Focus"])
        #expect(decoded.allSatisfy { $0.type == nil })
    }

    @Test("names alone leave the types out")
    func namesOnly() {
        let encoded = CachedEvent.encodeTagNames([EventTag(name: "Radiohead", type: "spotify_artist")])
        #expect(event(tagNames: encoded).decodedTagNames == ["Radiohead"])
        #expect(CachedEvent.encodeTagNames([]) == nil)
    }
}
