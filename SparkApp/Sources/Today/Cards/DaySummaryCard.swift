import SparkUI
import SwiftUI

/// Flint's short read of the day, written on device or on Private Cloud
/// Compute. It sits where the digest opener used to, and shows nothing when
/// no model produced a line.
///
/// A model wrote it, so it sits on the generated surface with Flint's glyph
/// and name in the eyebrow (`docs/design-language.md` section 3.5), and in the
/// reading face, like the rest of Flint's prose.
struct DaySummaryCard: View {
    let summary: String

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            HStack(spacing: SparkSpacing.xs + 2) {
                SparkGlyph(.flint, size: 12, relativeTo: .caption)
                Text("Flint")
                    .font(SparkTypography.captionStrong)
            }
            .foregroundStyle(.secondary)

            Text(summary)
                .font(SparkTypography.longFormBodySmall)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SparkSpacing.lg)
        .sparkGeneratedSurface(radius: SparkRadii.lg)
        .accessibilityElement(children: .combine)
    }
}
