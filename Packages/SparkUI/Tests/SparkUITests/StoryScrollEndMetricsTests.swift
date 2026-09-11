import Testing
@testable import SparkUI

@Suite("Story card end-of-content detection")
struct StoryScrollEndMetricsTests {
    @Test("content taller than the viewport is not at the end when scrolled to the top")
    func tallContentAtTopIsNotAtEnd() {
        let metrics = StoryScrollEndMetrics(offsetY: 0, containerHeight: 800, contentHeight: 2400)
        #expect(metrics.isAtEnd() == false)
    }

    @Test("content taller than the viewport is not at the end part-way down")
    func tallContentPartWayIsNotAtEnd() {
        let metrics = StoryScrollEndMetrics(offsetY: 700, containerHeight: 800, contentHeight: 2400)
        #expect(metrics.isAtEnd() == false)
    }

    @Test("scrolling to the bottom of tall content is at the end")
    func tallContentScrolledToBottomIsAtEnd() {
        let metrics = StoryScrollEndMetrics(offsetY: 1600, containerHeight: 800, contentHeight: 2400)
        #expect(metrics.isAtEnd() == true)
    }

    @Test("stopping just short of the bottom still counts, within the threshold")
    func withinThresholdOfBottomIsAtEnd() {
        // 10pt short of the true bottom, inside the 24pt threshold.
        let metrics = StoryScrollEndMetrics(offsetY: 1590, containerHeight: 800, contentHeight: 2400)
        #expect(metrics.isAtEnd() == true)
    }

    @Test("stopping well short of the bottom does not count")
    func outsideThresholdOfBottomIsNotAtEnd() {
        let metrics = StoryScrollEndMetrics(offsetY: 1560, containerHeight: 800, contentHeight: 2400)
        #expect(metrics.isAtEnd() == false)
    }

    // A card short enough to fit without scrolling is entirely visible, so
    // there is no "bottom" to reach. It is at the end from first layout and
    // only the dwell stands between it and being marked read.
    @Test("content shorter than the viewport is at the end immediately")
    func shortContentIsAtEnd() {
        let metrics = StoryScrollEndMetrics(offsetY: 0, containerHeight: 800, contentHeight: 300)
        #expect(metrics.isAtEnd() == true)
    }

    // This is the shipped bug: the old sentinel fired on first render, before
    // layout had resolved, so every card reported "read". Unresolved geometry
    // must produce no opinion at all.
    @Test("unresolved geometry is never at the end")
    func unresolvedGeometryIsNotAtEnd() {
        #expect(StoryScrollEndMetrics(offsetY: 0, containerHeight: 0, contentHeight: 0).isAtEnd() == false)
        #expect(StoryScrollEndMetrics(offsetY: 0, containerHeight: 800, contentHeight: 0).isAtEnd() == false)
        #expect(StoryScrollEndMetrics(offsetY: 0, containerHeight: 0, contentHeight: 2400).isAtEnd() == false)
    }
}

@Suite("Story card dwell arming")
struct StoryDwellKeyTests {
    @Test("the clock runs only on the active page, at the end, when not already read")
    func armsOnlyWhenAllConditionsHold() {
        #expect(StoryDwellKey(isActive: true, isAtEnd: true, alreadyRead: false).shouldArm == true)
    }

    // TabView(.page) builds the next page before the swipe lands, so an
    // off-screen card reaches the end of its content while the reader is still
    // on the previous one. Without the active gate it would be marked read
    // before ever being seen.
    @Test("an off-screen page never arms, even at the end of its content")
    func inactivePageDoesNotArm() {
        #expect(StoryDwellKey(isActive: false, isAtEnd: true, alreadyRead: false).shouldArm == false)
    }

    @Test("an active page that has not reached the end does not arm")
    func activeButNotAtEndDoesNotArm() {
        #expect(StoryDwellKey(isActive: true, isAtEnd: false, alreadyRead: false).shouldArm == false)
    }

    @Test("an already-read card does not re-arm")
    func alreadyReadDoesNotArm() {
        #expect(StoryDwellKey(isActive: true, isAtEnd: true, alreadyRead: true).shouldArm == false)
    }
}
