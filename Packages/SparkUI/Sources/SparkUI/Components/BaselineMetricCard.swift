import SwiftUI

/// One domain on the Day tab's metric grid.
///
/// Every card reads the same way: the domain and change on the left, today's
/// figure aligned with the title on the right, then the comparison bar and
/// two supporting rows beneath it.
///
/// The baseline tick makes domains with a reported baseline comparable at a
/// glance. A known zero can show its start marker without a baseline, while
/// an unavailable comparison otherwise leaves the track absent.
///
/// There is deliberately no glyph. The bar already carries the domain tint,
/// and four glyphs on one screen is decoration. A card whose service has not
/// reported says so where its figure would be, rather than presenting a stale
/// number as a fall.
public struct BaselineMetricCard: View {

    /// A label/value row under the bar. A `nil` value renders as an em dash,
    /// for a figure the app is waiting on rather than one that is zero.
    public struct Supporting: Sendable, Hashable {
        public let label: String
        public let value: String?

        public init(_ label: String, _ value: String?) {
            self.label = label
            self.value = value
        }
    }

    public enum Reading: Sendable, Hashable {
        /// A figure the app trusts, with an optional delta shown below the label.
        case value(String, delta: String?)
        /// The service has not reported yet. `reason` goes where the figure would.
        case waiting(String)
    }

    private let label: String
    private let tint: Color
    private let reading: Reading
    private let fill: Double?
    private let baseline: Double?
    private let isFlagged: Bool
    private let primary: Supporting
    private let secondary: Supporting

    /// - Parameters:
    ///   - label: the domain, in sentence case.
    ///   - tint: the domain tint; the bar is the only place it appears.
    ///   - reading: today's figure, or why there isn't one.
    ///   - fill: 0…1, today on the scale the bar draws. Zero is an explicit
    ///     measured zero; `nil` hides the track while retaining layout space.
    ///   - baseline: 0…1, the baseline on that same scale. `nil` draws no tick.
    ///   - isFlagged: draws the figure, its delta and the bar in ember. For a
    ///     day well outside its band, so that one value on the screen is
    ///     obviously the thing worth looking at.
    public init(
        label: String,
        tint: Color,
        reading: Reading,
        fill: Double?,
        baseline: Double? = nil,
        isFlagged: Bool = false,
        primary: Supporting,
        secondary: Supporting
    ) {
        self.label = label
        self.tint = tint
        self.reading = reading
        self.fill = fill
        self.baseline = baseline
        self.isFlagged = isFlagged
        self.primary = primary
        self.secondary = secondary
    }

    private var isWaiting: Bool {
        if case .waiting = reading { return true }
        return false
    }

    private var figureTint: Color {
        if isWaiting { return .secondary }
        return isFlagged ? .ember7 : .primary
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            bar
                .padding(.top, SparkSpacing.md)
            supportingRows
                .padding(.top, SparkSpacing.lg)
        }
        .padding(SparkSpacing.lg)
        .frame(maxWidth: .infinity, minHeight: 154, alignment: .leading)
        .sparkGlass(.roundedRect(SparkRadii.md))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: SparkSpacing.xs) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if case .value(_, let delta) = reading, let delta {
                    Text(delta)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(isFlagged ? AnyShapeStyle(Color.ember7) : AnyShapeStyle(.secondary))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: SparkSpacing.xs)

            figure
        }
    }

    @ViewBuilder
    private var figure: some View {
        switch reading {
        case .value(let text, _):
            Text(text)
                .font(SparkFonts.display(.title, weight: .bold))
                .foregroundStyle(figureTint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .multilineTextAlignment(.trailing)
        case .waiting(let reason):
            Text(reason)
                .font(SparkTypography.captionStrong)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    @ViewBuilder
    private var bar: some View {
        if !isWaiting, let fill {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(tint.opacity(0.15))

                    if fill == 0 {
                        Circle()
                            .fill(tint)
                            .frame(width: 6, height: 6)
                    } else {
                        Capsule()
                            .fill(isFlagged ? Color.ember7 : tint)
                            .frame(width: max(2, geo.size.width * clamp(fill)))
                    }

                    if let baseline {
                        Capsule()
                            .fill(Color.primary.opacity(0.42))
                            .frame(width: 1.5, height: 12)
                            .offset(x: geo.size.width * clamp(baseline) - 0.75)
                    }
                }
            }
            .frame(height: 6)
        } else {
            Color.clear.frame(height: 6)
        }
    }

    private var supportingRows: some View {
        VStack(spacing: SparkSpacing.sm) {
            supportingRow(primary)
            supportingRow(secondary)
        }
    }

    private func supportingRow(_ row: Supporting) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.xs) {
            Text(row.label)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: SparkSpacing.xs)

            Text(row.value ?? "—")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(row.value == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                .lineLimit(1)
        }
    }

    private func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    private var accessibilityLabel: String {
        var parts: [String] = [label]
        switch reading {
        case .value(let text, let delta):
            parts.append(text)
            if let delta { parts.append(delta) }
        case .waiting(let reason):
            parts.append(reason)
        }
        parts.append("\(primary.label) \(primary.value ?? "not available")")
        parts.append("\(secondary.label) \(secondary.value ?? "not available")")
        return parts.joined(separator: ", ")
    }
}
