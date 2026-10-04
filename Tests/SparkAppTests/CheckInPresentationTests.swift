import Foundation
import SwiftUI
import Testing
import UIKit

@testable import Spark
@testable import SparkUI

@Suite("Check-in mood scale")
struct CheckInMoodScaleTests {
    /// A physical score of 1...5 plus a mental score of 1...5, so the scale runs
    /// 2 through 10. The values are the design system's `mood-*` tokens.
    @Test("each score maps to its design system token")
    func scaleMatchesTokens() {
        #expect(Self.hex(CheckInPresentation.scoreColor(2)) == "D43D51")
        #expect(Self.hex(CheckInPresentation.scoreColor(3)) == "E27357")
        #expect(Self.hex(CheckInPresentation.scoreColor(4)) == "EBA06E")
        #expect(Self.hex(CheckInPresentation.scoreColor(5)) == "F2CA94")
        #expect(Self.hex(CheckInPresentation.scoreColor(6)) == "FDF1C5")
        #expect(Self.hex(CheckInPresentation.scoreColor(7)) == "CDD6A3")
        #expect(Self.hex(CheckInPresentation.scoreColor(8)) == "99BC89")
        #expect(Self.hex(CheckInPresentation.scoreColor(9)) == "60A277")
        #expect(Self.hex(CheckInPresentation.scoreColor(10)) == "00876C")
    }

    /// The scale diverges: red at the bottom, cream at the midpoint, green at
    /// the top. A step that broke that order would read as noise in the heatmap.
    @Test("the ramp runs red through cream to green")
    func rampDivergesInOrder() {
        for score in 2...6 {
            let (r, g, _) = Self.components(CheckInPresentation.scoreColor(score))
            #expect(r > g, "score \(score) should sit on the warm side")
        }
        for score in 8...10 {
            let (r, g, _) = Self.components(CheckInPresentation.scoreColor(score))
            #expect(g > r, "score \(score) should sit on the cool side")
        }
    }

    /// No step of the scale reaches 4.5:1 on the light ground, which is why the
    /// summary row sets its numeral in `sparkTextPrimary` and the heatmap cell
    /// carries an accessibility label. If a step ever did clear the bar, this
    /// test failing is the prompt to revisit that decision — not a regression.
    @Test("no step is legible as text on the light ground")
    func scaleIsFillOnly() {
        for score in 2...10 {
            let ratio = Self.contrast(CheckInPresentation.scoreColor(score), Self.lightGround)
            #expect(ratio < 4.5, "score \(score) now clears 4.5:1 as text")
        }
    }

    @Test("scores outside the scale fall back rather than crash")
    func outOfRangeScores() {
        #expect(CheckInPresentation.scoreColor(nil) == Color.secondary)
        #expect(CheckInPresentation.scoreColor(0) == Color.secondary)
        #expect(CheckInPresentation.scoreColor(1) == Color.secondary)
        #expect(CheckInPresentation.scoreColor(11) == Color.secondary)
    }

    private static let lightGround = Color.ash1

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

    private static func contrast(_ a: Color, _ b: Color) -> CGFloat {
        let (hi, lo) = (max(relativeLuminance(a), relativeLuminance(b)), min(relativeLuminance(a), relativeLuminance(b)))
        return (hi + 0.05) / (lo + 0.05)
    }
}
