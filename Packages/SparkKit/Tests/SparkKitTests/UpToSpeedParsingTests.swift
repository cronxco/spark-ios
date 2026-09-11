import Foundation
import Testing
@testable import SparkKit

@Suite("UpToSpeed content parsing")
struct UpToSpeedParsingTests {
    // Trimmed from the real Thursday news-roundup digest.
    private let newsSummary = """
    ## U.S.–Iran escalation is now visibly testing oil markets

    Brent crude has moved above $100 a barrel as the reported U.S.–Iran hostilities intensify. *The Economist*'s World in Brief on Thursday couples the price move with reported military strikes.

    Watch for evidence of actual, sustained disruption to shipping or production.

    ## Britain's air-traffic failure has become a mass-disruption event

    A British air-traffic-control outage grounded more than 1,900 flights, according to *The Economist*'s Thursday World in Brief. *POLITICO London Playbook* had framed the day before as a political reckoning.

    What is new since yesterday is that the disruption is no longer described only through "hundreds" of cancellations; the new briefing reports a 1,900-plus-flight event.

    Watch for NATS's account of cause, the duration of knock-on disruption, and whether the ministerial scrutiny produces a regulatory response.
    """

    @Test("splits a ## summary into one section per heading")
    func splitsSections() {
        let sections = UpToSpeedParsing.newsRoundupSections(from: newsSummary)
        #expect(sections.count == 2)
        #expect(sections[0].heading == "U.S.–Iran escalation is now visibly testing oil markets")
        #expect(sections[1].heading == "Britain's air-traffic failure has become a mass-disruption event")
        #expect(sections[0].id == 0)
        #expect(sections[1].id == 1)
    }

    @Test("pulls publication names from *italic* runs, deduped")
    func extractsSources() {
        let sections = UpToSpeedParsing.newsRoundupSections(from: newsSummary)
        #expect(sections[0].sources == ["The Economist"])
        #expect(sections[1].sources == ["The Economist", "POLITICO London Playbook"])
    }

    @Test("isolates the what's-new and watching lines")
    func extractsWhatsNewAndWatching() {
        let sections = UpToSpeedParsing.newsRoundupSections(from: newsSummary)

        #expect(sections[0].whatsNew == nil)
        #expect(sections[0].watching?.hasPrefix("Watch for evidence") == true)

        #expect(sections[1].whatsNew?.contains("1,900-plus-flight event") == true)
        #expect(sections[1].whatsNew?.lowercased().contains("new since yesterday") == false)
        #expect(sections[1].watching?.hasPrefix("Watch for NATS") == true)

        // The body should not repeat the watching sentence.
        #expect(sections[1].body.contains("Watch for NATS") == false)
    }

    @Test("**bold** markers are not treated as italic sources")
    func ignoresBoldMarkers() {
        let runs = UpToSpeedParsing.italicRuns(in: "A **bold** thing and an *italic* thing")
        #expect(runs == ["italic"])
    }

    @Test("parses the reading-list digest into a titled item")
    func parsesReadingItem() {
        let summary = "**[The French nuclear deterrent in a changing strategic environment]"
            + "(https://www.frstrategie.org/en/publications/notes/french-nuclear-deterrent)** — about 12 minutes. "
            + "With Ukraine diplomacy active again, this is a useful corrective to loose talk of a European nuclear substitute."
        let item = UpToSpeedParsing.readingItem(from: summary)
        #expect(item?.title == "The French nuclear deterrent in a changing strategic environment")
        #expect(item?.url == "https://www.frstrategie.org/en/publications/notes/french-nuclear-deterrent")
        #expect(item?.readingTime == "12 min")
        #expect(item?.blurb?.hasPrefix("With Ukraine diplomacy") == true)
    }

    @Test("reading item is nil for empty input")
    func readingItemNilForEmpty() {
        #expect(UpToSpeedParsing.readingItem(from: "   ") == nil)
    }

    @Test("opener paragraphs skip the greeting and ALL-CAPS headings")
    func openerParagraphs() {
        let summary = """
        Good Thursday morning.

        DRIVING THE DAY

        Readiness dropped hard overnight — 54, down 31% on baseline.

        WHAT YOU'VE BEEN UP TO

        Yesterday was a solid, uneventful office day.
        """
        let paragraphs = UpToSpeedParsing.openerParagraphs(from: summary, limit: 2)
        #expect(paragraphs.count == 2)
        #expect(paragraphs[0].hasPrefix("Readiness dropped hard"))
        #expect(paragraphs[1].hasPrefix("Yesterday was a solid"))
    }

    @Test("pulls a one-sentence yesterday recap from WHAT YOU'VE BEEN UP TO")
    func yesterdayRecap() {
        let summary = """
        Good Thursday morning.

        DRIVING THE DAY

        Readiness dropped hard overnight — 54, down 31% on baseline.

        WHAT YOU'VE BEEN UP TO —

        Yesterday was a solid, uneventful office day — the RSA breakfast with Daniel went to plan. Sleep was rough.

        COMING UP —

        Friday brings the start of Daniel's birthday weekend.
        """
        let recap = UpToSpeedParsing.yesterdayRecap(from: summary)
        #expect(recap == "Yesterday was a solid, uneventful office day — the RSA breakfast with Daniel went to plan")
    }

    @Test("yesterday recap is nil when the summary has no such section")
    func yesterdayRecapNilWhenAbsent() {
        let summary = """
        Good Thursday evening.

        THURSDAY CHEAT SHEET

        Quiet day, nothing notable.
        """
        #expect(UpToSpeedParsing.yesterdayRecap(from: summary) == nil)
    }
}
