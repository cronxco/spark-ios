import SparkKit
import SparkUI
import SwiftUI

/// One story from the Flint news roundup, ordered by what a reader needs from a
/// phone screen: the gist, the specifics, where accounts differ, why it
/// matters to them, what to watch, then the reporting to tap through to.
///
/// A roundup written as a TL;DR plus key points says each thing once. Older
/// roundups carried the same point in the lead, "More detail" and "Read the
/// whole roundup"; those disclosures remain only for digests of that shape.
///
/// This used to open on the sources and a hedge ("the supplied summaries do
/// not state…"), then repeat the same point in a grey-serif "Reporting" card,
/// an unlabelled watch line, and ingestion chips ("Newsletter Post ·
/// Newsletter") that opened a browser. Every card also carried the whole
/// roundup's prose behind "Read full roundup", which now appears only once, on
/// the last story.
struct NewsStoryScreen: View {
    let item: UpToSpeedItem
    let section: NewsRoundupSection
    let index: Int
    let total: Int
    var viewModel: UpToSpeedViewModel? = nil
    @State private var expanded = false
    @State private var roundupExpanded = false
    @State private var openArticle: UpToSpeedItem?
    @Environment(\.openURL) private var openURL
    var isActive: Bool = true
    let onReachedBottom: (() -> Void)?

    var body: some View {
        StoryScreenScaffold(
            flintByline: .init(meta: total > 1 ? "Story \(index + 1) of \(total)" : nil),
            isActive: isActive,
            onReachedBottom: onReachedBottom
        ) {
            VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                Text(section.heading)
                    .font(SparkTypography.heroSmall)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if let lead {
                    SparkRichContentText(
                        text: lead,
                        font: SparkTypography.longFormBody,
                        foregroundStyle: .primary,
                        lineSpacing: 4
                    )
                }

                if !section.keyPoints.isEmpty {
                    keyPoints
                }

                if let contested = section.contested {
                    labelled("Where accounts differ") {
                        Text(contested)
                            .font(SparkTypography.body)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let whyItMatters = section.whyItMatters, !whyItMatters.isEmpty {
                    labelled("Why it matters to you") {
                        Text(whyItMatters)
                            .font(SparkTypography.body)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let watching = section.watching, !watching.isEmpty {
                    watchCallout(watching)
                }

                if let whatsNew = section.whatsNew {
                    labelled("New since yesterday") {
                        Text(whatsNew)
                            .font(SparkTypography.body)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if !section.sourcePositions.isEmpty {
                    reportedBy
                }

                if let detail {
                    DisclosureGroup(
                        "More detail",
                        isExpanded: viewModel?.disclosureBinding("\(item.id)-news\(index)-analysis") ?? $expanded
                    ) {
                        SparkLongFormContentView(text: detail, tint: .sparkOcean, paragraphFont: SparkTypography.longFormBodySmall)
                            .padding(.top, SparkSpacing.md)
                    }
                    .font(SparkTypography.bodySmall)
                    .tint(Color.sparkOcean)
                }

                if let fullRoundup = section.fullRoundup, index == total - 1 {
                    DisclosureGroup(
                        "Read the whole roundup",
                        isExpanded: viewModel?.disclosureBinding("\(item.id)-roundup") ?? $roundupExpanded
                    ) {
                        SparkLongFormContentView(text: fullRoundup, tint: .sparkOcean, paragraphFont: SparkTypography.longFormBodySmall)
                            .padding(.top, SparkSpacing.md)
                    }
                    .font(SparkTypography.bodySmall)
                    .tint(Color.sparkOcean)
                }

                if let urlString = section.sourceURL, let url = URL(string: urlString) {
                    Link(destination: url) {
                        Label("Open source", systemImage: "arrow.up.right.square")
                            .font(SparkTypography.bodySmall)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .sheet(item: $openArticle) { article in
            NavigationStack {
                NewsSummaryScreen(item: article, isActive: false, onReachedBottom: nil, reserveTopSpace: false)
                    .sparkAppBackground()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { openArticle = nil }
                        }
                    }
            }
        }
    }

    // MARK: - Content

    /// The short standfirst where the skill wrote one; otherwise the body,
    /// which is then the only text there is.
    private var lead: String? {
        let text = section.standfirst ?? section.body
        return text.isEmpty ? nil : text
    }

    /// The longer write-up, behind a disclosure — but only when the lead above
    /// isn't already it.
    private var detail: String? {
        guard section.standfirst != nil, !section.body.isEmpty else { return nil }
        return section.body
    }

    // MARK: - Pieces

    private func labelled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.xs) {
            Text(title)
                .font(SparkTypography.captionStrong)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    /// Flint's forward look, named as such. It used to be an unlabelled
    /// fragment in the same card style as the sources.
    private func watchCallout(_ text: String) -> some View {
        HStack(alignment: .top, spacing: SparkSpacing.sm) {
            FlintAvatar(size: .sm)
            labelled("What to watch") {
                Text(text)
                    .font(SparkTypography.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(SparkSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.sparkOcean.opacity(0.08), in: RoundedRectangle(cornerRadius: SparkRadii.md, style: .continuous))
    }

    /// The specifics, as a list: each point carries one thing the lead doesn't.
    private var keyPoints: some View {
        labelled("What you need to know") {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                ForEach(Array(section.keyPoints.enumerated()), id: \.offset) { _, point in
                    HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.sm) {
                        Text("•")
                            .font(SparkTypography.body)
                            .foregroundStyle(Color.sparkOcean)
                            .accessibilityHidden(true)
                        SparkRichContentText(
                            text: point,
                            font: SparkTypography.body,
                            foregroundStyle: .primary,
                            lineSpacing: 2
                        )
                    }
                }
            }
        }
    }

    private var feedSources: [FlintNewsSource] { section.sourcePositions.filter { !$0.isResearch } }
    private var researchSources: [FlintNewsSource] { section.sourcePositions.filter(\.isResearch) }

    /// The reporting, one tappable row per outlet: the user's own issues open
    /// in the app, the roundup's research opens the article itself.
    private var reportedBy: some View {
        labelled("How it's been reported") {
            VStack(alignment: .leading, spacing: SparkSpacing.md) {
                if !feedSources.isEmpty {
                    sourceGroup(researchSources.isEmpty ? nil : "From your feeds", feedSources)
                }
                if !researchSources.isEmpty {
                    sourceGroup(feedSources.isEmpty ? nil : "Further reading", researchSources)
                }
            }
        }
    }

    private func sourceGroup(_ title: String?, _ sources: [FlintNewsSource]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(title)
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)
            }
            ForEach(Array(sources.enumerated()), id: \.offset) { offset, source in
                sourceButton(source)
                if offset < sources.count - 1 {
                    Divider().opacity(0.15)
                }
            }
        }
    }

    private func sourceButton(_ source: FlintNewsSource) -> some View {
        let article = viewModel?.citedArticle(for: source, in: section)
        let link = article == nil ? source.url.flatMap(URL.init(string:)) : nil
        let destination: SourceDestination?
        if article != nil {
            destination = .article
        } else if link != nil {
            destination = .web
        } else {
            destination = nil
        }

        return Button {
            if let article {
                openArticle = article
            } else if let link {
                openURL(link)
            }
        } label: {
            sourceRow(source, destination: destination)
        }
        .buttonStyle(.plain)
        .disabled(destination == nil)
        .accessibilityHint(destination.map { $0 == .web ? "Opens the article in your browser" : "Opens the issue" } ?? "")
    }

    private enum SourceDestination {
        case article, web
    }

    private func sourceRow(_ source: FlintNewsSource, destination: SourceDestination?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(source.publication)
                    .font(SparkTypography.bodyStrong)
                    .foregroundStyle(.primary)
                Text(source.position)
                    .font(SparkTypography.bodySmall)
                    .foregroundStyle(.primary.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if let destination {
                Image(systemName: destination == .web ? "arrow.up.right" : "chevron.right")
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, SparkSpacing.sm)
        .contentShape(Rectangle())
    }
}
