import Testing
import SwiftUI
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
