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

    // MARK: - Digest cards

    /// The 12 September evening digest, verbatim. Its six cheat-sheet lines are
    /// one `\n\n` chunk, which is exactly why the whole digest used to land on
    /// the opener and leave the briefing chapter with an empty card.
    private static let eveningSummary = """
    Good Saturday evening.

    SATURDAY CHEAT SHEET

    — Day two of the Newquay weekend stayed low-key: a long coastal walk was the extent of it.
    — Sleep was strong at 90 (+10% on baseline). Resilience read Adequate for a third day running.
    — This morning's open question about the wedding marker resolved itself before it needed asking again.
    — The bigger news: tomorrow isn't a trip home. You're moving on to Penryn by train.
    — Quiet spending: the daily savings-pot transfer and a £6 Patreon renewal, £11.10 in total.
    — Also worth a note: John of John got finished today, five stars on Goodreads.

    TOMORROW'S WORLD —

    Sunday stays overcast across Cornwall — high around 20-22°C in both Newquay and Penryn.
    """

    @Test("the evening cheat sheet becomes three cards, not one wall of text")
    func eveningDigestSplitsIntoCards() {
        let cards = UpToSpeedParsing.digestCards(from: Self.eveningSummary)

        #expect(cards.count == 3)
        // Greeting dropped — the opener says it in its own voice.
        #expect(!cards.contains { $0.contains("Good Saturday evening") })
        // Heading rides the first card only.
        #expect(cards[0].hasPrefix("SATURDAY CHEAT SHEET"))
        #expect(!cards[1].contains("SATURDAY CHEAT SHEET"))
        // Six bullets at a maximum of four come out evenly, not 4+2.
        #expect(cards[0].components(separatedBy: "— ").count - 1 == 3)
        #expect(cards[1].components(separatedBy: "— ").count - 1 == 3)
        #expect(cards[2].hasPrefix("TOMORROW'S WORLD"))
    }

    @Test("prose sections are never split, however long")
    func proseDigestKeepsItsSections() {
        let summary = """
        Good Saturday morning.

        DRIVING THE DAY

        Day two of the Newquay birthday weekend, and the weather's cooperating.

        Recovery is a genuine mixed picture. Sleep was strong — 90, +10% on baseline.

        WHAT YOU'VE BEEN UP TO —

        Friday's Newquay travel went as planned.

        COMING UP —

        Sunday turns wetter in Newquay.
        """
        let cards = UpToSpeedParsing.digestCards(from: summary)

        #expect(cards.count == 4)
        #expect(cards[0].hasPrefix("DRIVING THE DAY"))
        #expect(cards[1].hasPrefix("Recovery is a genuine mixed picture"))
        #expect(cards[2].hasPrefix("WHAT YOU'VE BEEN UP TO"))
        #expect(cards[3].hasPrefix("COMING UP"))
    }

    @Test("a list at the limit stays on one card")
    func shortListIsNotSplit() {
        let summary = """
        CHEAT SHEET

        — One.
        — Two.
        — Three.
        — Four.
        """
        let cards = UpToSpeedParsing.digestCards(from: summary)

        #expect(cards.count == 1)
        #expect(cards[0].hasPrefix("CHEAT SHEET"))
    }

    @Test("nine bullets split three ways rather than 4+4+1")
    func longListSplitsEvenly() {
        let bullets = (1...9).map { "— Item \($0)." }.joined(separator: "\n")
        let cards = UpToSpeedParsing.digestCards(from: "CHEAT SHEET\n\n" + bullets)

        #expect(cards.count == 3)
        for card in cards {
            #expect(card.components(separatedBy: "— ").count - 1 == 3)
        }
    }

    @Test("a summary with no headings still yields its paragraphs")
    func headinglessSummaryYieldsParagraphs() {
        let cards = UpToSpeedParsing.digestCards(from: "First paragraph.\n\nSecond paragraph.")

        #expect(cards == ["First paragraph.", "Second paragraph."])
    }

    @Test("an empty summary yields nothing")
    func emptySummaryYieldsNoCards() {
        #expect(UpToSpeedParsing.digestCards(from: "").isEmpty)
        #expect(UpToSpeedParsing.digestCards(from: "   \n\n  ").isEmpty)
    }

    /// The opener greets the reader itself, so a digest that opens with nothing
    /// but "Good Friday morning." would otherwise get a whole card for it.
    @Test("bare greetings are recognised, real prose is not")
    func bareGreetingDetection() {
        #expect(UpToSpeedParsing.isBareGreeting("Good Friday morning."))
        #expect(UpToSpeedParsing.isBareGreeting("Good Monday evening."))
        #expect(UpToSpeedParsing.isBareGreeting("Happy Friday!"))
        #expect(UpToSpeedParsing.isBareGreeting("Happy Friday afternoon."))
        #expect(!UpToSpeedParsing.isBareGreeting("Good news: inflation is falling."))
        #expect(!UpToSpeedParsing.isBareGreeting("Happy customers renewed their subscriptions."))
    }

    @Test("a heading with no body of its own is dropped")
    func headingOnlySectionIsDropped() {
        #expect(UpToSpeedParsing.digestCards(from: "DRIVING THE DAY").isEmpty)
    }
}
