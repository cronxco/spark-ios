import SparkKit
import SparkUI
import SwiftUI

/// One story from the Flint news roundup, laid out as an editorial page —
/// headline, serif body, a "new since yesterday" note and Flint's "what I'm
/// watching" line. Replaces rendering roundup blocks as generic insight cards.
struct NewsStoryScreen: View {
    let item: UpToSpeedItem
    let section: NewsRoundupSection
    let index: Int
    let total: Int
    var isActive: Bool = true
    let onReachedBottom: (() -> Void)?

    var body: some View {
        StoryScreenScaffold(
            flintByline: .init(meta: section.sources.isEmpty ? "News roundup" : section.sources.joined(separator: " · ")),
            isActive: isActive,
            onReachedBottom: onReachedBottom
        ) {
            VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                Text(section.heading)
                    .font(SparkTypography.heroSmall)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if !section.body.isEmpty {
                    SparkRichContentText(
                        text: section.body,
                        font: SparkTypography.body,
                        foregroundStyle: .primary,
                        lineSpacing: 6
                    )
                }

                if let whatsNew = section.whatsNew {
                    VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                        Text("New since yesterday")
                            .font(SparkTypography.captionStrong)
                            .tracking(0.8)
                            .foregroundStyle(.secondary)
                        Text(whatsNew)
                            .font(SparkTypography.body)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let watching = section.watching {
                    HStack(alignment: .top, spacing: SparkSpacing.sm) {
                        FlintAvatar(size: .sm)
                        Text(watching)
                            .font(SparkTypography.bodySmall)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(SparkSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .sparkGlass(.roundedRect(SparkRadii.md))
                }
            }
        }
    }

}
