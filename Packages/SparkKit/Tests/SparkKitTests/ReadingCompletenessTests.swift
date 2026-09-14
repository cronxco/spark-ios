import Foundation
import Testing
@testable import SparkKit

@Suite("Reading completeness")
struct ReadingCompletenessTests {
    @Test func mismatchedHeadlinesKeepRoundupReachableWithoutInventingAssociation() {
        let summary = """
        ## Different headline

        Long **analysis** with [source](https://example.com).

        ## Another heading

        Last paragraph.
        """
        let reference = EntityReference(type: .event, id: "source", title: "Source")
        let blocks = [
            FlintDigestBlock(
                id: "a", blockType: "flint_news", title: "Short headline",
                content: "Short *Publication* story", references: [reference]
            ),
            FlintDigestBlock(id: "b", blockType: "flint_news", title: "Second", content: "Another story"),
            FlintDigestBlock(id: "note", blockType: "flint_editorial_note", title: "Note", content: "Editorial note")
        ]

        let cards = UpToSpeedParsing.newsRoundupSections(blocks: blocks, summary: summary)
        #expect(cards.count == 2)
        #expect(cards.allSatisfy { $0.fullRoundup == summary && $0.analysis == nil })
        #expect(cards[0].references == [reference])
        #expect(cards[0].sourceURL == nil)
        #expect(cards[0].sources == ["Publication"])

        let summaryOnlyCards = UpToSpeedParsing.newsRoundupSections(blocks: [], summary: summary)
        #expect(summaryOnlyCards.count == 2)
        #expect(summaryOnlyCards.allSatisfy { $0.fullRoundup == nil })
        #expect(summaryOnlyCards[1].body == "Last paragraph.")
    }
}
