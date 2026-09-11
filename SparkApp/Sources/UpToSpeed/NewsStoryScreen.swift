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
    let onReachedBottom: (() -> Void)?

    var body: some View {
        StoryScreenScaffold(onReachedBottom: onReachedBottom) {
            VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                spine

                Text(section.heading)
                    .font(SparkTypography.hero)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if !section.body.isEmpty {
                    Text(bodyText)
                        .font(SparkTypography.longFormBody)
                        .foregroundStyle(.primary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let whatsNew = section.whatsNew {
                    VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                        Text("New since yesterday")
                            .font(SparkTypography.captionStrong)
                            .tracking(0.8)
                            .foregroundStyle(.secondary)
                        Text(whatsNew)
                            .font(SparkTypography.longFormBody)
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

    private var spine: some View {
        HStack(spacing: SparkSpacing.sm) {
            Text(total > 1 ? "Story \(index + 1) / \(total)" : "News")
                .font(SparkTypography.caption)
                .tracking(1.2)
                .foregroundStyle(Color.sparkOcean)
            Rectangle()
                .fill(Color.sparkOcean.opacity(0.25))
                .frame(height: 1)
            if !section.sources.isEmpty {
                Text(section.sources.joined(separator: " · "))
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    /// Strip inline markdown emphasis for plain serif rendering.
    private var bodyText: String {
        section.body
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "*", with: "")
    }
}
