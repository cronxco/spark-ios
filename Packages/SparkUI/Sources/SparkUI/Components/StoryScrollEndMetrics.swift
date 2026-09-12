import CoreGraphics

/// Whether the reader has reached the end of a story card's content.
///
/// Extracted from `StoryScreenScaffold` so the rule is testable on its own —
/// it decides when a card counts as finished, which in turn decides when an
/// Up to Speed item is marked caught up.
struct StoryScrollEndMetrics: Equatable {
    /// How close to the end of the content counts as being at the end.
    static let defaultThreshold: CGFloat = 24

    let offsetY: CGFloat
    let containerHeight: CGFloat
    let contentHeight: CGFloat

    init(offsetY: CGFloat, containerHeight: CGFloat, contentHeight: CGFloat) {
        self.offsetY = offsetY
        self.containerHeight = containerHeight
        self.contentHeight = contentHeight
    }

    func isAtEnd(threshold: CGFloat = StoryScrollEndMetrics.defaultThreshold) -> Bool {
        // Nothing laid out yet — no opinion either way.
        guard contentHeight > 0, containerHeight > 0 else { return false }
        // Content fits the viewport, so all of it is already on screen. The
        // reader is at the end by definition and only the dwell remains.
        guard contentHeight > containerHeight else { return true }
        return offsetY + containerHeight >= contentHeight - threshold
    }
}

/// The three facts that decide whether the "finished reading" clock should be
/// running. Restarting a `.task` keyed on this cancels an in-flight dwell, so
/// scrolling back up or swiping to another page stops the clock.
struct StoryDwellKey: Equatable {
    let isActive: Bool
    let isAtEnd: Bool
    let alreadyRead: Bool

    var shouldArm: Bool { isActive && isAtEnd && !alreadyRead }
}
