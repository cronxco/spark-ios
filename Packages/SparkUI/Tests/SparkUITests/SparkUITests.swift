import Testing
import SwiftUI
import SparkKit
#if canImport(UIKit)
import UIKit
#endif
@testable import SparkUI

@Suite("Spark app background phase")
struct SparkAppBackgroundPhaseTests {
    @Test("auto light mode resolves expected day phases")
    func autoLightModePhases() throws {
        #expect(phase(hour: 5, colorScheme: .light) == .eveningLight)
        #expect(phase(hour: 6, colorScheme: .light) == .morning)
        #expect(phase(hour: 9, colorScheme: .light) == .morning)
        #expect(phase(hour: 10, colorScheme: .light) == .day)
        #expect(phase(hour: 16, colorScheme: .light) == .day)
        #expect(phase(hour: 17, colorScheme: .light) == .eveningLight)
        #expect(phase(hour: 22, colorScheme: .light) == .eveningLight)
    }

    @Test("auto dark mode resolves evening and night phases")
    func autoDarkModePhases() throws {
        #expect(phase(hour: 5, colorScheme: .dark) == .night)
        #expect(phase(hour: 6, colorScheme: .dark) == .eveningDark)
        #expect(phase(hour: 21, colorScheme: .dark) == .eveningDark)
        #expect(phase(hour: 22, colorScheme: .dark) == .night)
    }

    @Test("manual modes resolve independently of auto time buckets")
    func manualModePhases() throws {
        let date = try #require(Self.date(hour: 12))

        #expect(SparkAppBackgroundPhase.resolve(mode: .morning, date: date, colorScheme: .dark) == .morning)
        #expect(SparkAppBackgroundPhase.resolve(mode: .day, date: date, colorScheme: .dark) == .day)
        #expect(SparkAppBackgroundPhase.resolve(mode: .evening, date: date, colorScheme: .light) == .eveningLight)
        #expect(SparkAppBackgroundPhase.resolve(mode: .evening, date: date, colorScheme: .dark) == .eveningDark)
        #expect(SparkAppBackgroundPhase.resolve(mode: .night, date: date, colorScheme: .light) == .night)
    }

    private func phase(hour: Int, colorScheme: ColorScheme) throws -> SparkAppBackgroundPhase {
        let date = try #require(Self.date(hour: hour))
        return SparkAppBackgroundPhase.resolve(
            mode: .auto,
            date: date,
            calendar: Self.calendar,
            colorScheme: colorScheme
        )
    }

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private static func date(hour: Int) -> Date? {
        DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 5, day: 4, hour: hour).date
    }
}

@Suite("Spark long-form content parsing")
struct SparkLongFormContentParsingTests {
    @Test("parses headings paragraphs quotes and bullets")
    func parsesLongFormBlocks() {
        let blocks = SparkLongFormBlock.parse("""
        # Digest

        The day started well.

        > Keep an eye on recovery.

        - Hydrate
        - Read later
        """)

        #expect(blocks == [
            .heading("Digest", level: 1),
            .paragraph("The day started well."),
            .quote("Keep an eye on recovery."),
            .bullets(["Hydrate", "Read later"]),
        ])
    }

    @Test("plain markdown inline text stays a paragraph")
    func parsesInlineMarkdownAsParagraph() {
        let blocks = SparkLongFormBlock.parse("This has **emphasis** but remains one paragraph.")

        #expect(blocks == [.paragraph("This has **emphasis** but remains one paragraph.")])
    }
}

@Suite("Tag presentation")
struct SparkTagPresentationTests {
    @Test("wildcard type matching classifies people")
    func wildcardPersonTypes() {
        #expect(EventTag(name: "Alice", type: "spark_person").tagPresentation.kind == .person)
        #expect(EventTag(name: "u/example", type: "reddit_user").tagPresentation.kind == .person)
        #expect(EventTag(name: "Will", type: "email_contact").tagPresentation.kind == .person)
    }

    @Test("wildcard type matching classifies places and topics")
    func wildcardPlaceAndTopicTypes() {
        #expect(EventTag(name: "Prufrock", type: "merchant_category").tagPresentation.kind == .topic)
        #expect(EventTag(name: "London", type: "geo_place").tagPresentation.kind == .place)
        #expect(EventTag(name: "Swift", type: "spark_topic").tagPresentation.kind == .topic)
    }

    @Test("unknown typed tags stay typed and legacy strings stay neutral")
    func unknownAndUntypedTags() {
        let unknown = EventTag(name: "Inbox", type: "custom_bucket").tagPresentation
        #expect(unknown.kind == .unknownTyped)
        #expect(unknown.label == "Custom Bucket")

        let untyped = EventTag(name: "news").tagPresentation
        #expect(untyped.kind == .untyped)
        #expect(untyped.label == nil)
    }
}

@Suite("Long-form bullet markers")
struct SparkLongFormBulletTests {
    /// Flint writes its cheat sheets with em dashes. The renderer only knew
    /// `-`, `*` and `•`, so a six-item list arrived as one run-on paragraph.
    @Test("em-dash and en-dash lines parse as bullets")
    func dashBulletsAreBullets() {
        let text = "— First item.\n— Second item.\n— Third item."
        let blocks = SparkLongFormBlock.parse(text)

        #expect(blocks == [.bullets(["First item.", "Second item.", "Third item."])])

        let enDash = SparkLongFormBlock.parse("– One.\n– Two.")
        #expect(enDash == [.bullets(["One.", "Two."])])
    }

    @Test("the established markers still parse as bullets")
    func classicBulletsStillWork() {
        #expect(SparkLongFormBlock.parse("- One.\n* Two.\n• Three.")
            == [.bullets(["One.", "Two.", "Three."])])
    }

    /// A dash used mid-sentence is punctuation, not a list.
    @Test("a mid-sentence em dash stays prose")
    func inlineDashIsNotABullet() {
        let text = "Sleep was strong at 90 — well above baseline."
        #expect(SparkLongFormBlock.parse(text) == [.paragraph(text)])
    }
}

#if canImport(UIKit)
@Suite("Brand palette ramps")
struct SparkPaletteTests {
    /// Flame and Ember used to be crossed: `flame100`/`flame200` held Ember's
    /// orange, `ember100`–`ember300` held Flame's red, and `spark500`–`spark700`
    /// held more of Ember. Each name is now one family on a 0–9 ramp, matching
    /// the design system's `tokens.json`. These assertions pin the values so the
    /// families cannot drift back into each other.

    @Test("Flame is the red ramp")
    func flameIsRed() {
        #expect(Self.hex(.flame0) == "FDEEEC")
        #expect(Self.hex(.flame2) == "F8C1B9")
        #expect(Self.hex(.flame3) == "F5A499")
        #expect(Self.hex(.flame5) == "EE6352")
        #expect(Self.hex(.flame7) == "B02411")
        #expect(Self.hex(.flame9) == "3C0C06")
    }

    @Test("Ember is the orange ramp")
    func emberIsOrange() {
        #expect(Self.hex(.ember0) == "FEF5EB")
        #expect(Self.hex(.ember3) == "FABD7F")
        #expect(Self.hex(.ember4) == "F9A653")
        #expect(Self.hex(.ember5) == "F79129")
        #expect(Self.hex(.ember7) == "A75706")
        #expect(Self.hex(.ember9) == "361C02")
    }

    @Test("Spark is the amber ramp and 5 is the brand primary")
    func sparkIsAmber() {
        #expect(Self.hex(.spark0) == "FFF9E5")
        #expect(Self.hex(.spark2) == "FFE699")
        #expect(Self.hex(.spark3) == "FFD966")
        #expect(Self.hex(.spark5) == "FFBF00")
        #expect(Self.hex(.spark7) == "997300")
        #expect(Self.hex(.spark9) == "332600")
    }

    /// The bug was that two names resolved to the same colour across families.
    @Test("no colour appears in two warm families")
    func warmFamiliesAreDisjoint() {
        let flame = Set((0...9).map { Self.hex(Self.flame[$0]) })
        let ember = Set((0...9).map { Self.hex(Self.ember[$0]) })
        let spark = Set((0...9).map { Self.hex(Self.spark[$0]) })

        #expect(flame.isDisjoint(with: ember))
        #expect(flame.isDisjoint(with: spark))
        #expect(ember.isDisjoint(with: spark))
    }

    @Test("each ramp darkens from 0 to 9")
    func rampsDarkenMonotonically() {
        for ramp in [Self.flame, Self.ember, Self.spark] {
            let luminances = ramp.map(Self.relativeLuminance)
            for (lighter, darker) in zip(luminances, luminances.dropFirst()) {
                #expect(lighter > darker)
            }
        }
    }

    @Test("semantic tokens point at the right family")
    func semanticsBindToCorrectFamilies() {
        #expect(Self.hex(.sparkAccent) == Self.hex(.spark5))
        #expect(Self.hex(.domainMoney) == Self.hex(.spark5))
        #expect(Self.hex(.domainActivity) == Self.hex(.ember5))
        #expect(Self.hex(.domainMedia) == Self.hex(.flame5))
    }

    private static let flame: [Color] = [.flame0, .flame1, .flame2, .flame3, .flame4, .flame5, .flame6, .flame7, .flame8, .flame9]
    private static let ember: [Color] = [.ember0, .ember1, .ember2, .ember3, .ember4, .ember5, .ember6, .ember7, .ember8, .ember9]
    private static let spark: [Color] = [.spark0, .spark1, .spark2, .spark3, .spark4, .spark5, .spark6, .spark7, .spark8, .spark9]

    private static func components(_ color: Color) -> (CGFloat, CGFloat, CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b)
    }

    private static func hex(_ color: Color) -> String {
        let (r, g, b) = components(color)
        return String(format: "%02X%02X%02X", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }

    private static func relativeLuminance(_ color: Color) -> CGFloat {
        let (r, g, b) = components(color)
        func channel(_ c: CGFloat) -> CGFloat {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }
}
#endif
