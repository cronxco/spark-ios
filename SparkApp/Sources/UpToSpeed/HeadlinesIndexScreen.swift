import SparkKit
import SparkUI
import SwiftUI

/// The contents page for the Headlines tier: every individual article, one
/// line each, so the reader can see the whole pile before deciding which to
/// open. Articles the roundup drew on come first, tagged with their story.
///
/// These used to follow the roundup's stories as more "News" cards behind a
/// single counter — sixteen cards with nothing to say which three were the
/// point.
struct HeadlinesIndexScreen: View {
    let articles: [UpToSpeedItem]
    let citedStories: [String: Int]
    let viewModel: UpToSpeedViewModel
    var isActive: Bool = true
    let onReachedBottom: (() -> Void)?

    var body: some View {
        StoryScreenScaffold(
            flintByline: .init(meta: articles.count == 1 ? "1 article" : "\(articles.count) articles"),
            isActive: isActive,
            onReachedBottom: onReachedBottom
        ) {
            VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                Text("Also in your news")
                    .font(SparkTypography.heroSmall)
                    .foregroundStyle(.primary)

                Text("Everything behind today's stories, and the rest of what arrived. Tap one to read it, or swipe through them all.")
                    .font(SparkTypography.bodySmall)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !cited.isEmpty {
                    group("Behind today's stories", cited)
                }
                if !uncited.isEmpty {
                    group(cited.isEmpty ? "Articles" : "Everything else", uncited)
                }
            }
        }
    }

    private var cited: [UpToSpeedItem] { articles.filter { citedStories[$0.id] != nil } }
    private var uncited: [UpToSpeedItem] { articles.filter { citedStories[$0.id] == nil } }

    private func group(_ title: String, _ items: [UpToSpeedItem]) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            Text(title)
                .font(SparkTypography.bodyStrong)
                .accessibilityAddTraits(.isHeader)
            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { offset, item in
                        Button {
                            if let index = viewModel.articleScreenIndex(itemID: item.id) {
                                viewModel.jump(to: index)
                            }
                        } label: {
                            row(item)
                        }
                        .buttonStyle(.plain)

                        if offset < items.count - 1 {
                            Divider().opacity(0.15)
                        }
                    }
                }
            }
        }
    }

    private func row(_ item: UpToSpeedItem) -> some View {
        let news = Self.news(in: item)
        return HStack(alignment: .top, spacing: SparkSpacing.md) {
            VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                HStack(spacing: SparkSpacing.sm) {
                    if let news {
                        Text(NewsSummaryScreen.publication(for: news))
                            .font(SparkTypography.captionStrong)
                            .foregroundStyle(.secondary)
                    }
                    if let story = citedStories[item.id] {
                        Text("Story \(story)")
                            .font(SparkTypography.caption)
                            .foregroundStyle(Color.sparkOcean)
                            .padding(.horizontal, SparkSpacing.sm)
                            .padding(.vertical, 2)
                            .background(Color.sparkOcean.opacity(0.12), in: Capsule())
                    }
                    if viewModel.isMarkedRead(item.id) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(SparkTypography.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Read")
                    }
                }
                Text(news?.title ?? "Untitled")
                    .font(SparkTypography.bodyStrong)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let tldr = news?.tldr, !tldr.isEmpty {
                    Text(Self.plain(tldr))
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(.primary.opacity(0.75))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(SparkTypography.caption)
                .foregroundStyle(.secondary)
                .padding(.top, SparkSpacing.xs)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, SparkSpacing.lg)
        .padding(.vertical, SparkSpacing.md)
        .contentShape(Rectangle())
    }

    private static func news(in item: UpToSpeedItem) -> NewsSummary? {
        if case .newsSummary(let news) = item.payload { return news }
        return nil
    }

    /// The TL;DR arrives wrapped in `**…**` for the article page's standfirst;
    /// a two-line preview wants it plain.
    static func plain(_ text: String) -> String {
        text.replacingOccurrences(of: "**", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
