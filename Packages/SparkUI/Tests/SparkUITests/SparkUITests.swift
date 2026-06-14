import Testing
import SwiftUI
import SparkKit
@testable import SparkUI

@Suite("Spark date formatting")
struct SparkDateFormattingTests {
    @Test("short time respects 12-hour and 24-hour locale preferences")
    func shortTimeRespectsLocale() throws {
        let date = try #require(Self.date)
        let timeZone = try #require(TimeZone(secondsFromGMT: 0))

        #expect(
            SparkDateFormatting.shortTime(
                date,
                locale: Locale(identifier: "en_US"),
                timeZone: timeZone
            ).contains("1:05")
        )
        #expect(
            SparkDateFormatting.shortTime(
                date,
                locale: Locale(identifier: "en_US"),
                timeZone: timeZone
            ).localizedCaseInsensitiveContains("PM")
        )
        #expect(
            SparkDateFormatting.shortTime(
                date,
                locale: Locale(identifier: "en_GB"),
                timeZone: timeZone
            ) == "13:05"
        )
    }

    private static let date = ISO8601DateFormatter().date(from: "2026-06-14T13:05:00Z")
}

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
