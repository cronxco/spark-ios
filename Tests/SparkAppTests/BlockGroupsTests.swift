import Foundation
import SparkKit
import Testing

@testable import Spark

@Suite("Event detail block groups")
struct BlockGroupsTests {
    /// The newsletter event from 19 Oct: six text blocks, four of them
    /// versions of the same summary.
    @Test("takeaways read inline, summaries fold away, the rest are rows")
    func groupsNewsletterBlocks() {
        let blocks = [
            Block(id: "1", blockType: "newsletter_content", title: "Issue Content", content: "Full issue"),
            Block(id: "2", blockType: "newsletter_tldr", title: "TL;DR", content: "Short"),
            Block(id: "3", blockType: "newsletter_key_takeaways", title: "Key Takeaways", content: "- One\n- Two"),
            Block(id: "4", blockType: "newsletter_summary_tweet", title: "Tweet Summary", content: "Tweet"),
            Block(id: "5", blockType: "newsletter_summary_short", title: "Short Summary", content: "Short"),
            Block(id: "6", blockType: "newsletter_summary_paragraph", title: "Paragraph Summary", content: "Para"),
        ]

        let groups = BlockGroups(blocks)

        #expect(groups.takeaways.map(\.id) == ["3"])
        #expect(groups.rows.map(\.id) == ["1"])
        #expect(groups.summaries.map(\.id) == ["2", "4", "5", "6"])
        #expect(groups.values.isEmpty)
    }

    @Test("blocks with a numeric value keep the tile grid")
    func numericBlocksAreTiles() {
        let groups = BlockGroups([Block(id: "1", blockType: "heart_rate_summary", title: "Average", value: "62", unit: "bpm")])
        #expect(groups.values.map(\.id) == ["1"])
        #expect(groups.summaries.isEmpty)
    }

    @Test("previews drop markdown and join lines")
    func previewIsPlainText() {
        let block = Block(id: "1", blockType: "note", title: "Note", content: "## Heading\n\n**Bold** line\n- item")
        #expect(BlockGroups.preview(for: block) == "Heading Bold line - item")
    }
}
