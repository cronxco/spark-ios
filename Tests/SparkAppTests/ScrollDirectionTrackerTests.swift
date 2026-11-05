import CoreGraphics
import Foundation
import Testing

@testable import Spark

@Suite("Top bar scroll direction")
@MainActor
struct ScrollDirectionTrackerTests {
    /// Feeds offsets one second apart, well past the settle time, so only
    /// the movement decides.
    @MainActor
    private final class Feed {
        let tracker = ScrollDirectionTracker()
        var now: TimeInterval = 0

        func step(_ old: CGFloat, _ new: CGFloat, isShown: Bool, after seconds: TimeInterval = 1) -> Bool? {
            now += seconds
            return tracker.update(from: old, to: new, isShown: isShown, now: now)
        }
    }

    @Test func showsTheBarNearTheTop() {
        let feed = Feed()
        #expect(feed.step(0, 20, isShown: false) == true)
        #expect(feed.step(20, 10, isShown: true) == nil)
    }

    @Test func hidesTheBarAfterASlowScrollDown() {
        let feed = Feed()
        _ = feed.step(0, 30, isShown: true)
        var results: [Bool?] = []
        var offset: CGFloat = 100
        while offset < 140 {
            results.append(feed.step(offset, offset + 3, isShown: true))
            offset += 3
        }
        #expect(results.contains(false))
    }

    @Test func showsTheBarAfterASlowScrollBackUp() {
        let feed = Feed()
        #expect(feed.step(200, 300, isShown: true) == false)
        var results: [Bool?] = []
        var offset: CGFloat = 300
        while offset > 260 {
            results.append(feed.step(offset, offset - 3, isShown: false))
            offset -= 3
        }
        #expect(results.contains(true))
    }

    @Test func ignoresSmallJitter() {
        let feed = Feed()
        #expect(feed.step(200, 300, isShown: true) == false)
        #expect(feed.step(300, 296, isShown: false) == nil)
        #expect(feed.step(296, 300, isShown: false) == nil)
    }

    @Test func hidesTheBarWhenAScrollDownWobbles() {
        let feed = Feed()
        let offsets: [CGFloat] = [42, 41, 45, 44, 48, 47, 51]
        var previous: CGFloat = 38
        var results: [Bool?] = []
        for offset in offsets {
            results.append(feed.step(previous, offset, isShown: true))
            previous = offset
        }
        #expect(results.contains(false))
    }

    /// The froze-the-page loop: hiding the buttons resized the bar, the page
    /// jumped by the bar's height, and the jump read as a scroll back up.
    @Test func ignoresThePageJumpAfterAFlip() {
        let feed = Feed()
        #expect(feed.step(200, 300, isShown: true) == false)
        #expect(feed.step(300, 256, isShown: false, after: 0.05) == nil)
        #expect(feed.step(256, 300, isShown: false, after: 0.05) == nil)
        // Once settled, it measures from where the page came to rest.
        #expect(feed.step(300, 296, isShown: false, after: 1) == nil)
        #expect(feed.step(296, 280, isShown: false, after: 0.1) == true)
    }
}
