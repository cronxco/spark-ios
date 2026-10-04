import SparkUI
import SwiftUI

struct HeatmapSection: View {
    let rows: [DomainHeatmapRow]

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            HStack {
                Text("Last 45 days")
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("← older")
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
            }

            GlassCard(radius: SparkRadii.lg, padding: SparkSpacing.lg) {
                Heatmap45(rows: rows)
            }
        }
    }
}
