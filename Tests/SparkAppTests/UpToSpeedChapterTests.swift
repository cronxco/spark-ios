import Foundation
import SwiftUI
import Testing

@testable import Spark
@testable import SparkUI

@Suite("Up to Speed chapters")
struct UpToSpeedChapterTests {
    @Test func groupsConsecutiveScreensBySharedKind() {
        let keys: [UpToSpeedChapter.Kind] = [
            .intro,
            .anomaly,
            .digest(title: "Morning Digest"),
            .digest(title: "Morning Digest"),
            .day,
            .news, .news, .news,
            .wrap, .wrap,
        ]

        let chapters = UpToSpeedChapter.chapters(for: keys)

        #expect(chapters.map(\.kind) == [
            .intro,
            .anomaly,
            .digest(title: "Morning Digest"),
            .day,
            .news,
            .wrap,
        ])
        #expect(chapters.map(\.cardCount) == [1, 1, 2, 1, 3, 2])
        #expect(chapters[3].range == 4..<5)
        #expect(chapters[4].range == 5..<8)
        #expect(chapters[5].range == 8..<10)
        #expect(chapters[3].title == "Your day")
        #expect(chapters[3].shortLabel == "Day")
    }

    @Test func distinctDigestTitlesStayInSeparateChapters() {
        let chapters = UpToSpeedChapter.chapters(for: [
            .digest(title: "Morning Digest"),
            .digest(title: "Evening Digest"),
        ])

        #expect(chapters.count == 2)
        #expect(chapters[0].title == "Morning Digest")
        #expect(chapters[1].title == "Evening Digest")
    }

    @Test func emptyInputProducesNoChapters() {
        #expect(UpToSpeedChapter.chapters(for: []).isEmpty)
    }

    @Test func chapterAccentsMatchTheirKind() {
        let chapters = UpToSpeedChapter.chapters(for: [.anomaly, .day, .news, .wrap])
        #expect(chapters[0].accent == .sparkWarning)
        #expect(chapters[1].accent == .sparkAccent)
        #expect(chapters[2].accent == .sparkOcean)
        #expect(chapters[3].accent == .sparkSuccess)
    }
}
