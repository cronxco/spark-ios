import SwiftUI

public struct MetricCard: View {
    let title: String
    let value: String
    let unit: String?
    let caption: String?
    let trend: Trend?

    public enum Trend: Sendable {
        case up
        case down
        case flat
    }

    public init(title: String, value: String, unit: String? = nil, caption: String? = nil, trend: Trend? = nil) {
        self.title = title
        self.value = value
        self.unit = unit
        self.caption = caption
        self.trend = trend
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            HStack {
                Text(title)
                    .font(SparkTypography.captionStrong)
                    .foregroundStyle(.secondary)
                Spacer()
                if let trend {
                    Image(systemName: trend.icon)
                        .font(.caption)
                        .foregroundStyle(trend.color)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.xs) {
                Text(value)
                    .font(SparkTypography.display)
                if let unit {
                    Text(unit)
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(.secondary)
                }
            }
            if let caption {
                Text(caption)
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(SparkSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sparkGlass(.roundedRect(SparkRadii.lg))
    }
}

private extension MetricCard.Trend {
    var icon: String {
        switch self {
        case .up: "arrow.up.right"
        case .down: "arrow.down.right"
        case .flat: "arrow.right"
        }
    }

    var color: Color {
        switch self {
        case .up: .sparkPositive
        case .down: .sparkNegative
        case .flat: .secondary
        }
    }
}

#Preview("Light + Dark + XXL") {
    VStack(spacing: SparkSpacing.md) {
        MetricCard(title: "Sleep", value: "7.4", unit: "h", caption: "+0.3 vs 7-day avg", trend: .up)
        MetricCard(title: "Spend", value: "£42.10", caption: "Under £50 cap", trend: .down)
    }
    .padding()
    .background(Color.sparkSurface)
}
