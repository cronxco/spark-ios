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
        // Regression: the prefix strip used to remove every leading i/s
        // character rather than the complete word "is", truncating the start
        // of the sentence (e.g. dropping into "...that the disruption...").
        #expect(sections[1].whatsNew?.hasPrefix("That the disruption is no longer described") == true)
        #expect(sections[1].watching?.hasPrefix("Watch for NATS") == true)

        // The body should not repeat the watching sentence.
        #expect(sections[1].body.contains("Watch for NATS") == false)
    }

    @Test("strips only the complete 'is' prefix, not a run of i/s characters")
    func stripsWhatsNewPrefixExactly() {
        // "is slowing" used to lose its first four characters ("is s") to a
        // drop-while over individual i/s/space/separator characters.
        let sections = UpToSpeedParsing.newsRoundupSections(
            from: "## Heading\n\nNew since yesterday is slowing global trade further."
        )
        #expect(sections[0].whatsNew == "Slowing global trade further.")
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

    @Test("matches the longer 'min read' form before the shorter 'min' alternative")
    func parsesReadingItemWithMinReadFormat() {
        // "mins?" used to match "min" first, leaving "read." as the start of the blurb.
        let summary = "**[A Long Read]"
            + "(https://example.com/article)** — 12 min read. Worth the time."
        let item = UpToSpeedParsing.readingItem(from: summary)
        #expect(item?.readingTime == "12 min")
        #expect(item?.blurb == "Worth the time.")
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

    // MARK: - Opener overlap

    /// The opener card leads with the digest's first paragraphs and the
    /// briefing chapter then rendered them again, so the reader met the same
    /// prose twice within a few swipes.
    @Test("a section the opener already carries is recognised")
    func sectionShownInOpenerIsDetected() {
        let paragraph = "Today isn't the office day the calendar still claims — you and Dan are both on annual leave."
        let section = "DRIVING THE DAY\n\n\(paragraph)"

        #expect(UpToSpeedParsing.sectionIsShownInOpener(section, openerParagraphs: [paragraph]))
    }

    @Test("a section the opener does not carry is kept")
    func unseenSectionIsKept() {
        let section = "COMING UP —\n\nSaturday turns drier in Newquay."

        #expect(!UpToSpeedParsing.sectionIsShownInOpener(
            section,
            openerParagraphs: ["Today isn't the office day the calendar still claims."]
        ))
    }

    /// The opener shows the greeting as its headline. Leaving it in the digest
    /// too gave the briefing a whole card holding only "Good Friday morning."
    @Test("a bare greeting section is treated as already shown")
    func greetingSectionIsDropped() {
        #expect(UpToSpeedParsing.sectionIsShownInOpener("Good Friday morning.", openerParagraphs: []))
        #expect(UpToSpeedParsing.sectionIsShownInOpener("Good Monday evening.", openerParagraphs: []))
        #expect(UpToSpeedParsing.sectionIsShownInOpener("Happy Friday!", openerParagraphs: []))
        #expect(UpToSpeedParsing.sectionIsShownInOpener("Happy Friday afternoon.", openerParagraphs: []))
    }

    @Test("substantive prose beginning with a positive word is kept")
    func positiveOpeningProseIsKept() {
        #expect(!UpToSpeedParsing.sectionIsShownInOpener(
            "Good news: inflation is falling.",
            openerParagraphs: []
        ))
        #expect(!UpToSpeedParsing.sectionIsShownInOpener(
            "Happy customers renewed their subscriptions.",
            openerParagraphs: []
        ))
    }

    @Test("a heading with no body is treated as already shown")
    func headingOnlySectionIsDropped() {
        #expect(UpToSpeedParsing.sectionIsShownInOpener("DRIVING THE DAY", openerParagraphs: []))
    }

    @Test("matching ignores incidental whitespace differences")
    func matchIgnoresWhitespace() {
        let section = "DRIVING THE DAY\n\nToday isn't  the office day\nthe calendar still claims."

        #expect(UpToSpeedParsing.sectionIsShownInOpener(
            section,
            openerParagraphs: ["Today isn't the office day the calendar still claims."]
        ))
    }

    @Test("a section containing both opener paragraphs is recognised")
    func joinedOpenerParagraphsAreDetected() {
        let first = "Readiness dropped hard overnight."
        let second = "Your afternoon is clear for focused work."
        let section = "DRIVING THE DAY\n\n\(first)\n\n\(second)"

        #expect(UpToSpeedParsing.sectionIsShownInOpener(
            section,
            openerParagraphs: [first, second]
        ))
        #expect(!UpToSpeedParsing.sectionIsShownInOpener(
            section,
            openerParagraphs: [second, first]
        ))
    }

    @Test("an empty opener keeps every real section")
    func emptyOpenerKeepsProse() {
        let section = "DRIVING THE DAY\n\nToday isn't the office day the calendar still claims."

        #expect(!UpToSpeedParsing.sectionIsShownInOpener(section, openerParagraphs: []))
    }
}
