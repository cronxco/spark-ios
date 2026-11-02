import CoreGraphics
import Testing

@testable import Spark

@Suite("Top bar scroll direction")
@MainActor
struct ScrollDirectionTrackerTests {
    @Test func showsTheBarNearTheTop() {
        let tracker = ScrollDirectionTracker()
        #expect(tracker.update(from: 0, to: 20, isShown: false) == true)
    }

    @Test func hidesTheBarAfterASlowScrollDown() {
        let tracker = ScrollDirectionTracker()
        _ = tracker.update(from: 0, to: 30, isShown: true)
        var results: [Bool?] = []
        var offset: CGFloat = 100
        while offset < 140 {
            results.append(tracker.update(from: offset, to: offset + 3, isShown: true))
            offset += 3
        }
        #expect(results.contains(false))
    }

    @Test func showsTheBarAfterASlowScrollBackUp() {
        let tracker = ScrollDirectionTracker()
        #expect(tracker.update(from: 200, to: 300, isShown: true) == false)
        var results: [Bool?] = []
        var offset: CGFloat = 300
        while offset > 260 {
            results.append(tracker.update(from: offset, to: offset - 3, isShown: false))
            offset -= 3
        }
        #expect(results.contains(true))
    }

    @Test func ignoresSmallJitter() {
        let tracker = ScrollDirectionTracker()
        #expect(tracker.update(from: 200, to: 300, isShown: true) == false)
        #expect(tracker.update(from: 300, to: 296, isShown: false) == nil)
        #expect(tracker.update(from: 296, to: 300, isShown: false) == nil)
    }

    @Test func hidesTheBarWhenAScrollDownWobbles() {
        let tracker = ScrollDirectionTracker()
        let offsets: [CGFloat] = [42, 41, 45, 44, 48, 47, 51]
        var previous: CGFloat = 38
        var results: [Bool?] = []
        for offset in offsets {
            results.append(tracker.update(from: previous, to: offset, isShown: true))
            previous = offset
        }
        #expect(results.contains(false))
    }
}
