import SwiftUI

/// One cell in a metric grid — a caption, a hero value, and a delta note.
/// Used by the Up to Speed anomaly screen's 2×2 readout. `emphasis` tints the
/// cell (rose) and the delta when the metric is the one being flagged.
public struct MetricDeltaCard: View {
    public enum Emphasis {
        /// The flagged metric — tinted surface, warning-coloured delta.
        case flagged
        /// A supporting metric — plain glass, muted delta.
        case neutral
        /// A supporting metric that reads reassuringly (e.g. "on baseline").
        case reassuring
    }

    private let label: String
    private let value: String
    private let unit: String?
    private let delta: String?
    private let emphasis: Emphasis

    public init(
        label: String,
        value: String,
        unit: String? = nil,
        delta: String? = nil,
        emphasis: Emphasis = .neutral
    ) {
        self.label = label
        self.value = value
        self.unit = unit
        self.delta = delta
        self.emphasis = emphasis
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            Text(label.uppercased())
                .font(SparkTypography.caption)
                .tracking(1.1)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(SparkFonts.display(.title, weight: .bold))
                    .foregroundStyle(valueColor)
                    .minimumScaleFactor(0.8)
                    .lineLimit(2)
                if let unit {
                    Text(unit)
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(.secondary)
                }
            }

            if let delta {
                Text(delta)
                    .font(SparkTypography.captionStrong)
                    .foregroundStyle(deltaColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SparkSpacing.lg)
        .sparkGlass(.roundedRect(SparkRadii.lg), tint: tint)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue([value, unit, delta].compactMap { $0 }.joined(separator: ", "))
    }

    /// `.reassuring` now carries a surface of its own: it backs anomalies whose
    /// movement is welcome — a balance up, a resting heart rate down — which
    /// previously had to borrow the flagged rose and read as a warning.
    private var tint: Color? {
        switch emphasis {
        case .flagged: Color.sparkWarning.opacity(0.12)
        case .reassuring: Color.sparkSuccess.opacity(0.12)
        case .neutral: nil
        }
    }

    private var valueColor: Color {
        switch emphasis {
        case .flagged: Color.sparkWarning
        case .reassuring: Color.sparkSuccess
        case .neutral: .primary
        }
    }

    private var deltaColor: Color {
        switch emphasis {
        case .flagged: Color.sparkWarning
        case .reassuring: Color.sparkSuccess
        case .neutral: .secondary
        }
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: SparkSpacing.md) {
        MetricDeltaCard(label: "Readiness", value: "54", delta: "−31%", emphasis: .flagged)
        MetricDeltaCard(label: "Sleep", value: "81", delta: "on baseline", emphasis: .reassuring)
        MetricDeltaCard(label: "Resilience", value: "2", delta: "−38%", emphasis: .flagged)
        MetricDeltaCard(label: "HRV", value: "40.5", unit: "ms", delta: "−16%", emphasis: .neutral)
    }
    .padding()
    .background(Color.sparkSurface)
}
