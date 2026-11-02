import Foundation
import Testing

@testable import SparkKit

@Suite("Block kinds")
struct BlockKindTests {
    @Test("model-written summaries are AI summaries, whatever the service")
    func aiSummaries() {
        for type in ["newsletter_tldr", "fetch_tldr", "newsletter_summary_paragraph", "fetch_summary_short",
                     "newsletter_summary_tweet", "bookmark_summary"] {
            #expect(BlockKind(blockType: type) == .aiSummary, "\(type)")
            #expect(BlockKind(blockType: type).isAIWritten)
        }
    }

    /// The old substring match folded these away with the AI summaries.
    @Test("summaries that aren't written by a model aren't AI summaries")
    func nonAISummaries() {
        #expect(BlockKind(blockType: "receipt_tax_summary") == .receiptTaxSummary)
        #expect(BlockKind(blockType: "cluster_summary") == .clusterSummary)
        #expect(BlockKind(blockType: "exercise_summary") == .exerciseSummary)
        #expect(BlockKind(blockType: "route_summary") == .genericContent)
        #expect(BlockKind(blockType: "stress_day_summary", hasValue: true) == .genericValue)
    }

    @Test("takeaways, content and raw are matched by suffix")
    func suffixes() {
        #expect(BlockKind(blockType: "newsletter_key_takeaways") == .takeaways)
        #expect(BlockKind(blockType: "fetch_key_takeaways") == .takeaways)
        #expect(BlockKind(blockType: "newsletter_content") == .content)
        #expect(BlockKind(blockType: "content") == .content)
        #expect(BlockKind(blockType: "raw_content") == .raw)
        #expect(BlockKind(blockType: "spotify_raw") == .raw)
        #expect(BlockKind(blockType: "pot_withdrawal") == .genericContent)
    }

    @Test("types with a layout get their own kind")
    func exactTypes() {
        #expect(BlockKind(blockType: "heart_rate") == .heartRate)
        #expect(BlockKind(blockType: "Album_Art") == .albumArt)
        #expect(BlockKind(blockType: "track_details") == .track)
        #expect(BlockKind(blockType: "receipt_line_item") == .receiptLineItem)
        #expect(BlockKind(blockType: "day_task") == .dayTask)
    }

    @Test("unknown types fall back on whether they carry a value")
    func fallbacks() {
        #expect(BlockKind(blockType: "something_new") == .genericContent)
        #expect(BlockKind(blockType: "something_new", hasValue: true) == .genericValue)
        #expect(Block(id: "1", blockType: "something_new", title: "", value: "4").kind == .genericValue)
        #expect(Block(id: "1", blockType: "something_new", title: "", value: "").kind == .genericContent)
    }

    @Test("Flint types are Flint kinds")
    func flint() {
        #expect(BlockKind(blockType: "flint_user_question") == .flintQuestion)
        #expect(BlockKind(blockType: "flint_day_context") == .flintDayContext)
        #expect(BlockKind(blockType: "flint_news").isFlint)
        #expect(!BlockKind(blockType: "newsletter_tldr").isFlint)
    }

    @Test("previews drop markdown and join lines")
    func previewIsPlainText() {
        let block = Block(id: "1", blockType: "note", title: "Note", content: "## Heading\n\n**Bold** line\n- item")
        #expect(block.preview == "Heading Bold line - item")
    }

    @Test("a track's preview is its first line")
    func trackPreviewIsFirstLine() {
        let block = Block(id: "1", blockType: "track_details", title: "Track Details",
                          content: "3:42, Between Worlds\n\nPopularity 39 out of 100")
        #expect(block.preview == "3:42, Between Worlds")
    }

    @Test("episode artwork is album art")
    func episodeArt() {
        #expect(BlockKind(blockType: "episode_art", hasValue: true) == .albumArt)
    }

    /// Spotify sent an image's width and a track's popularity as values,
    /// which drew "640 pixels" and "39 popularity" tiles.
    @Test("images and tracks show no value")
    func mediaValuesAreHidden() {
        let art = Block(id: "1", blockType: "album_art", title: "Album Art", value: "640", unit: "pixels")
        let track = Block(id: "2", blockType: "track_details", title: "Track Details", value: "39", unit: "popularity")
        let heartRate = Block(id: "3", blockType: "heart_rate", title: "Heart rate", value: "62", unit: "bpm")
        #expect(art.displayValue == nil)
        #expect(track.displayValue == nil)
        #expect(heartRate.displayValue != nil)
    }
}
