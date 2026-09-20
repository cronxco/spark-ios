import Foundation
import Testing
@testable import SparkKit

/// The Up to Speed flow used to rebuild a roundup's stories and a reading
/// list's picks out of the digest's prose, because the skills wrote nothing
/// structured. Now they do, and these cover both the new path and the fallback
/// that keeps the back catalogue readable.
@Suite("UpToSpeed block parsing")
struct UpToSpeedBlockParsingTests {
    private func block(
        _ type: String,
        title: String,
        content: String? = nil,
        url: String? = nil,
        minutes: Int? = nil
    ) -> FlintDigestBlock {
        FlintDigestBlock(
            id: UUID().uuidString,
            blockType: type,
            title: title,
            content: content,
            url: url,
            minutes: minutes
        )
    }

    // MARK: - News roundup

    @Test("builds one section per flint_news block")
    func sectionsFromBlocks() {
        let blocks = [
            block("flint_news", title: "Mocha seizure", content: "*The Economist* reports the port was taken."),
            block("flint_news", title: "Ukraine strike", content: "*POLITICO* reports £100m of air defences."),
            block("flint_editorial_note", title: "Run notes", content: "Six newsletters."),
        ]

        let sections = UpToSpeedParsing.newsRoundupSections(blocks: blocks, summary: "## Ignored\n\nProse.")

        #expect(sections.count == 2)
        #expect(sections[0].heading == "Mocha seizure")
        #expect(sections[0].sources == ["The Economist"])
        #expect(sections[1].heading == "Ukraine strike")
        // The block is already the short version — claiming to have found a
        // "what's new" or "watch next" in it would be inventing structure.
        #expect(sections[0].whatsNew == nil)
        #expect(sections[0].watching == nil)
    }

    @Test("uses structured news instead of reparsing prose")
    func structuredNewsSections() {
        let block = FlintDigestBlock(
            id: "story-1",
            blockType: "flint_news",
            title: "Rates hold",
            content: "Legacy fallback.",
            news: FlintNewsContent(
                summary: "The Bank held rates.",
                sources: [FlintNewsSource(publication: "The Economist", position: "Focused on inflation.")],
                whyItMatters: "Mortgage pricing may remain stable.",
                whatToWatch: "The next inflation release."
            )
        )

        let section = UpToSpeedParsing.newsRoundupSections(blocks: [block], summary: "")[0]

        #expect(section.body == "The Bank held rates.")
        #expect(section.sources == ["The Economist"])
        #expect(section.sourcePositions.first?.position == "Focused on inflation.")
        #expect(section.whyItMatters == "Mortgage pricing may remain stable.")
        #expect(section.watching == "The next inflation release.")
    }

    @Test("falls back to splitting the summary when there are no news blocks")
    func sectionsFallBackToProse() {
        let summary = """
        ## First story

        *The Economist* reported it. Watch for the next vote.

        ## Second story

        *POLITICO* reported it.
        """

        let sections = UpToSpeedParsing.newsRoundupSections(blocks: [], summary: summary)

        #expect(sections.count == 2)
        #expect(sections[0].heading == "First story")
    }

    @Test("an editorial note alone does not count as a story")
    func editorialOnlyFallsBack() {
        let blocks = [block("flint_editorial_note", title: "Run notes", content: "Nothing ran.")]

        let sections = UpToSpeedParsing.newsRoundupSections(blocks: blocks, summary: "## A story\n\nBody.")

        #expect(sections.count == 1)
        #expect(sections[0].heading == "A story")
    }

    // MARK: - Reading list

    /// The regex could only ever recover one item, so a digest with two picks
    /// showed one of them.
    @Test("returns every pick, not just the first")
    func allPicksFromBlocks() {
        let blocks = [
            block("flint_reading_pick", title: "Reversing UK rail tickets",
                  content: "You are on the Paddington leg today.",
                  url: "https://eta.st/rail", minutes: 15),
            block("flint_reading_pick", title: "ScotRail announcements",
                  content: "A lighter train read.",
                  url: "https://example.com/scotrail", minutes: 8),
        ]

        let picks = UpToSpeedParsing.readingItems(blocks: blocks, summary: "")

        #expect(picks.count == 2)
        #expect(picks[0].title == "Reversing UK rail tickets")
        #expect(picks[0].url == "https://eta.st/rail")
        #expect(picks[0].readingTime == "15 min")
        #expect(picks[1].readingTime == "8 min")
    }

    /// In prose a "Worth dropping" line is shaped exactly like a pick, so the
    /// parser could offer something to delete as something to read.
    @Test("a drop is never offered as a pick")
    func dropsAreExcluded() {
        let blocks = [
            block("flint_reading_pick", title: "Worth your evening", url: "https://example.com/a", minutes: 12),
            block("flint_reading_drop", title: "What If Trump Loses", url: "https://example.com/b"),
        ]

        let picks = UpToSpeedParsing.readingItems(blocks: blocks, summary: "")

        #expect(picks.count == 1)
        #expect(picks[0].title == "Worth your evening")
    }

    @Test("falls back to the prose parser when there are no pick blocks")
    func picksFallBackToProse() {
        let summary = "**[A saved piece](https://example.com/p)** — about 12 minutes. Why tonight."

        let picks = UpToSpeedParsing.readingItems(blocks: [], summary: summary)

        #expect(picks.count == 1)
        #expect(picks[0].url == "https://example.com/p")
        #expect(picks[0].readingTime == "12 min")
    }

    @Test("no picks and no parseable prose yields nothing")
    func emptyYieldsNothing() {
        let picks = UpToSpeedParsing.readingItems(blocks: [], summary: "")

        #expect(picks.isEmpty)
    }
}
