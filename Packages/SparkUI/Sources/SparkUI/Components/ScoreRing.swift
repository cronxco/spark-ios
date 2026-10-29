import SwiftUI

/// The ring pattern (`docs/design-language.md` §8): a ratio with a known
/// maximum, drawn as the hero of its card with the number inside. About
/// 128pt on a card and 64pt when compact. The track is the same fill at 15%.
/// An optional threshold, the provider's "excellent" line (85 for Oura),
/// draws a short tick across the ring.
///
/// Widgets and complications keep `Gauge(.accessoryCircularCapacity)`.
public struct ScoreRing: View {
    let fraction: Double
    let text: String
    let tint: Color
    let diameter: CGFloat
    let threshold: Double?

    /// - Parameters:
    ///   - fraction: the share of the maximum reached, 0...1.
    ///   - text: the number shown inside, already formatted.
    ///   - threshold: the "excellent" line as a share of the maximum, 0...1.
    public init(fraction: Double, text: String, tint: Color, diameter: CGFloat = 128, threshold: Double? = nil) {
        self.fraction = min(max(fraction, 0), 1)
        self.text = text
        self.tint = tint
        self.diameter = diameter
        self.threshold = threshold.map { min(max($0, 0), 1) }
    }

    private var lineWidth: CGFloat { max(6, diameter * 0.09) }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if let threshold {
                Capsule()
                    .fill(Color.primary.opacity(0.7))
                    .frame(width: 2, height: lineWidth + 4)
                    .offset(y: -(diameter - lineWidth) / 2)
                    .rotationEffect(.degrees(360 * threshold))
            }
            Text(text)
                .font(diameter >= 100 ? SparkFonts.display(.largeTitle, weight: .bold) : SparkFonts.display(.title3, weight: .bold))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(lineWidth + 2)
        }
        .frame(width: diameter, height: diameter)
    }
}
