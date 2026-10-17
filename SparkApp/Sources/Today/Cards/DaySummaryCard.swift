import SparkUI
import SwiftUI

/// Flint's short read of the day, written on device or on Private Cloud
/// Compute. It sits where the digest opener used to, and shows nothing when
/// no model produced a line.
struct DaySummaryCard: View {
    let summary: String

    var body: some View {
        Text(summary)
            .font(SparkTypography.body)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(SparkSpacing.lg)
            .sparkGlass(.roundedRect(SparkRadii.lg))
            .accessibilityElement(children: .combine)
    }
}
