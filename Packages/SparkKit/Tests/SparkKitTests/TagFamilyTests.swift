import Foundation
import Testing
@testable import SparkKit

@Suite("Tag families")
struct TagFamilyTests {
    @Test("types fall into their families")
    func familyMapping() {
        #expect(TagFamily(tagType: "spark") == .yours)
        #expect(TagFamily(tagType: nil) == .yours)
        #expect(TagFamily(tagType: "untyped") == .yours)
        #expect(TagFamily(tagType: "person") == .people)
        #expect(TagFamily(tagType: "music_artist") == .music)
        #expect(TagFamily(tagType: "spotify_context") == .music)
        #expect(TagFamily(tagType: "podcast_publisher") == .music)
        #expect(TagFamily(tagType: "transaction_category") == .spending)
        #expect(TagFamily(tagType: "merchant_emoji") == .spending)
        #expect(TagFamily(tagType: "transaction_scheme") == .paymentDetails)
        #expect(TagFamily(tagType: "transaction_something_new") == .paymentDetails)
        #expect(TagFamily(tagType: "card_pan") == .paymentDetails)
        #expect(TagFamily(tagType: "emoji") == .other)
    }

    @Test("type names read in sentence case")
    func typeNames() {
        #expect(TagTypeName.plural("music_artist") == "Artists")
        #expect(TagTypeName.plural("merchant_country") == "Countries")
        #expect(TagTypeName.plural("some_new_type") == "Some new type")
        #expect(TagTypeName.singular("music_album") == "Music album")
        #expect(TagTypeName.singular("spark") == "Your tag")
        #expect(TagTypeName.singular(nil) == "Tag")
    }

    @Test("sections use the server's totals for size and rank")
    func sectionsWithTotals() throws {
        let tags = [
            tag("1", "RAYE", "music_artist", 18),
            tag("2", "Judah Earl", "music_artist", 13),
            tag("3", "RENT", "music_album", 27),
            tag("4", "debit", "transaction_type", 55),
            tag("5", "Lunch", "spark", 2),
        ]
        let totals = [
            TagTypeTotal(type: "transaction_type", tagsCount: 1, totalCount: 55),
            TagTypeTotal(type: "music_artist", tagsCount: 30, totalCount: 120),
            TagTypeTotal(type: "music_album", tagsCount: 13, totalCount: 80),
            TagTypeTotal(type: "spark", tagsCount: 2, totalCount: 4),
        ]

        let sections = TagCatalogue.sections(tags: tags, totals: totals, perGroup: 1)

        #expect(sections.map(\.family) == [.yours, .music, .paymentDetails])
        let music = try #require(sections.first { $0.family == .music })
        #expect(music.groups.map(\.type) == ["music_artist", "music_album"])
        #expect(music.groups[0].tags.map(\.name) == ["RAYE"])
        #expect(music.groups[0].hiddenCount == 29)
        #expect(music.tagsCount == 43)
    }

    @Test("type sections keep related types together, most used first")
    func typeSections() {
        let tags = [
            tag("1", "RAYE", "music_artist", 18),
            tag("2", "RENT", "music_album", 27),
            tag("3", "debit", "transaction_type", 55),
            tag("4", "Lunch", "spark", 2),
            tag("5", "bills", "transaction_category", 10),
        ]
        let groups = TagCatalogue.typeSections(tags: tags, totals: nil)
        #expect(groups.map(\.type) == ["spark", "music_album", "music_artist", "transaction_category", "transaction_type"])
        #expect(groups.last?.family == .paymentDetails)
    }

    @Test("without totals, sizes come from what has loaded")
    func sectionsWithoutTotals() throws {
        let tags = [tag("1", "RAYE", "music_artist", 18), tag("2", "Judah Earl", "music_artist", 13)]
        let sections = TagCatalogue.sections(tags: tags, totals: nil)
        let group = try #require(sections.first?.groups.first)
        #expect(group.tagsCount == 2)
        #expect(group.totalCount == 31)
        #expect(group.hiddenCount == 0)
    }

    @Test("most used leaves out payment details")
    func mostUsed() {
        let tags = [
            tag("1", "debit", "transaction_type", 55),
            tag("2", "album", "spotify_context", 75),
            tag("3", "entertainment", "transaction_category", 29),
            tag("4", "unused", "spark", 0),
        ]
        #expect(TagCatalogue.mostUsed(tags).map(\.name) == ["album", "entertainment"])
    }

    @Test("the first page decodes per-type totals")
    func decodesTypes() throws {
        let page = try JSONDecoder().decode(TagPage.self, from: Data("""
        {"data":[],"next_cursor":null,"has_more":false,"types":[{"type":"music_artist","tags_count":30,"total_count":120}]}
        """.utf8))
        #expect(page.types == [TagTypeTotal(type: "music_artist", tagsCount: 30, totalCount: 120)])
    }

    @Test("list sends the type filter")
    func listSendsType() {
        let endpoint = TagsEndpoint.list(type: "music_artist")
        #expect(endpoint.query.contains(URLQueryItem(name: "type", value: "music_artist")))
        #expect(!TagsEndpoint.list().query.contains { $0.name == "type" })
    }

    private func tag(_ id: String, _ name: String, _ type: String, _ count: Int) -> TagResource {
        TagResource(id: id, name: name, type: type, eventsCount: count, objectsCount: 0)
    }
}
