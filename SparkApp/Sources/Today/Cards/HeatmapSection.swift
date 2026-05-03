import SparkUI
import SwiftUI

struct HeatmapSection: View {
    let rows: [DomainHeatmapRow]

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            HStack {
                Text("Last 45 days")
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text("← older")
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.secondary)
            }

            GlassCard(radius: SparkRadii.lg, padding: SparkSpacing.lg) {
                Heatmap45(rows: rows)
            }
        }
    }
}
