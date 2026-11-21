import Foundation
import Testing
@testable import SparkKit

@Suite("Markdown blocks")
struct MarkdownBlocksTests {
    /// The shape of the Ask Flint answer that ran together on screen:
    /// "then picks up:Sun 22: …".
    private static let weekAhead = """
    Your calendar looks fairly light early in the week, then picks up:

    - **Sun 22:** F1: Las Vegas Grand Prix at **04:00**; *Garry Starr Classic Penguins* at **17:30**. [Garry Starr Classic Penguins](https://spark.cronx.co/events/5f0c1d2e-3a4b-4c5d-8e9f-0a1b2c3d4e5f)
    - **Mon 23:** No calendar events listed.
    - **Tue 24:** Daniel at the dentist, **09:00–09:30**.
    """

    @Test("a list after a paragraph keeps its breaks")
    func listAfterParagraph() {
        let blocks = MarkdownBlocks.parse(Self.weekAhead)

        #expect(blocks.map(\.kind) == [
            .paragraph,
            .listItem(marker: "•", depth: 1),
            .listItem(marker: "•", depth: 1),
            .listItem(marker: "•", depth: 1),
        ])
        #expect(blocks[0].plainText == "Your calendar looks fairly light early in the week, then picks up:")
        #expect(blocks[2].plainText == "Mon 23: No calendar events listed.")

        let flat = String(MarkdownBlocks.flattened(blocks).characters)
        #expect(flat.contains("then picks up:\n\n• Sun 22: F1"))
        #expect(flat.contains("Penguins\n• Mon 23:"))
        #expect(!flat.contains("up:Sun"))
    }

    @Test("links and emphasis survive")
    func inlineStylingSurvives() throws {
        let item = try #require(MarkdownBlocks.parse(Self.weekAhead).dropFirst().first)

        let links = item.content.runs.compactMap { $0.link }
        #expect(links == [URL(string: "https://spark.cronx.co/events/5f0c1d2e-3a4b-4c5d-8e9f-0a1b2c3d4e5f")])
        #expect(item.content.runs.contains { $0.inlinePresentationIntent == .stronglyEmphasized })
    }

    @Test("ordered lists number their items")
    func orderedList() {
        let blocks = MarkdownBlocks.parse("Steps:\n\n1. Open it\n2. Read it\n3. Close it")

        #expect(blocks.dropFirst().map(\.kind) == [
            .listItem(marker: "1.", depth: 1),
            .listItem(marker: "2.", depth: 1),
            .listItem(marker: "3.", depth: 1),
        ])
        #expect(String(MarkdownBlocks.flattened(blocks).characters) == "Steps:\n\n1. Open it\n2. Read it\n3. Close it")
    }

    @Test("a nested list is one level deeper")
    func nestedList() {
        let blocks = MarkdownBlocks.parse("- Week\n    - Sunday\n    - Monday\n- Weekend")

        #expect(blocks.map(\.kind) == [
            .listItem(marker: "•", depth: 1),
            .listItem(marker: "•", depth: 2),
            .listItem(marker: "•", depth: 2),
            .listItem(marker: "•", depth: 1),
        ])
    }

    @Test("a second paragraph in an item has no marker of its own")
    func listItemContinuation() {
        let blocks = MarkdownBlocks.parse("- First line\n\n  More about it\n- Next")

        #expect(blocks.map(\.kind) == [
            .listItem(marker: "•", depth: 1),
            .listItem(marker: nil, depth: 1),
            .listItem(marker: "•", depth: 1),
        ])
    }

    @Test("headings are their own block, in bold when flattened")
    func headings() throws {
        let blocks = MarkdownBlocks.parse("## The week\nIt starts slowly.")

        #expect(blocks.map(\.kind) == [.heading(level: 2), .paragraph])
        let flat = MarkdownBlocks.flattened(blocks)
        #expect(String(flat.characters) == "The week\nIt starts slowly.")
        let first = try #require(flat.runs.first)
        #expect(first.inlinePresentationIntent == .stronglyEmphasized)
    }

    @Test("a lone newline is a line break, not a run-on")
    func loneNewlineBreaks() throws {
        let blocks = MarkdownBlocks.parse("**Sun 22:** Grand Prix\n**Mon 23:** Nothing")

        let paragraph = try #require(blocks.first)
        #expect(blocks.count == 1)
        #expect(!paragraph.plainText.contains("PrixMon"))
        #expect(!paragraph.plainText.contains("Prix Mon"))
        #expect(paragraph.plainText.contains { $0.isNewline })
    }

    @Test("code keeps its own lines and gains no break markers")
    func codeBlock() throws {
        let blocks = MarkdownBlocks.parse("Run:\n\n```sh\nswift test\nswift build\n```")

        let code = try #require(blocks.last)
        #expect(code.kind == .code(language: "sh"))
        #expect(code.plainText == "swift test\nswift build")
    }

    @Test("one line of inline Markdown is one paragraph")
    func inlineOnly() {
        let blocks = MarkdownBlocks.parse("Slept **7h 55m**, [details](https://spark.cronx.co/events/x)")

        #expect(blocks.count == 1)
        #expect(blocks.first?.kind == .paragraph)
        #expect(blocks.first?.plainText == "Slept 7h 55m, details")
    }

    @Test("empty text has no blocks")
    func empty() {
        #expect(MarkdownBlocks.parse("  \n ").isEmpty)
    }

    @Test("line breaks are only added inside running text")
    func lineBreakRewrite() {
        #expect(MarkdownBlocks.withLineBreaks("one\ntwo") == "one  \ntwo")
        #expect(MarkdownBlocks.withLineBreaks("intro\n- a\n- b") == "intro\n- a\n- b")
        #expect(MarkdownBlocks.withLineBreaks("one\n\ntwo") == "one\n\ntwo")
        #expect(MarkdownBlocks.withLineBreaks("```\na\nb\n```") == "```\na\nb\n```")
        #expect(MarkdownBlocks.withLineBreaks("# Title\nbody") == "# Title\nbody")
        #expect(MarkdownBlocks.withLineBreaks("Title\n===") == "Title\n===")
    }
}
