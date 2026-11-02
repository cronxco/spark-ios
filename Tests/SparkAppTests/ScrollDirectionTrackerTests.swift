import CoreGraphics
import Testing

@testable import Spark

@Suite("Top bar scroll direction")
@MainActor
struct ScrollDirectionTrackerTests {
    @Test func showsTheBarNearTheTop() {
        let tracker = ScrollDirectionTracker()
        #expect(tracker.update(from: 0, to: 20) == true)
    }

    @Test func hidesTheBarAfterASlowScrollDown() {
        let tracker = ScrollDirectionTracker()
        _ = tracker.update(from: 0, to: 30)
        var results: [Bool?] = []
        var offset: CGFloat = 100
        while offset < 140 {
            results.append(tracker.update(from: offset, to: offset + 3))
            offset += 3
        }
        #expect(results.contains(false))
    }

    @Test func showsTheBarAfterASlowScrollBackUp() {
        let tracker = ScrollDirectionTracker()
        #expect(tracker.update(from: 200, to: 300) == false)
        var results: [Bool?] = []
        var offset: CGFloat = 300
        while offset > 260 {
            results.append(tracker.update(from: offset, to: offset - 3))
            offset -= 3
        }
        #expect(results.contains(true))
    }

    @Test func ignoresSmallJitter() {
        let tracker = ScrollDirectionTracker()
        #expect(tracker.update(from: 200, to: 300) == false)
        #expect(tracker.update(from: 300, to: 296) == nil)
        #expect(tracker.update(from: 296, to: 300) == nil)
    }
}
