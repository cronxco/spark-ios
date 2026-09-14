import SparkKit
import SparkUI
import SwiftUI

/// Renders a news_summary Up to Speed item: headline, then the same story at
/// increasing length — TL;DR as a standfirst, the key points, the summary, and
/// the full article behind a disclosure.
///
/// The TL;DR used to sit in a tinted bubble with the summary and key points
/// folded away behind "More detail", and the article opened a modal sheet that
/// left the flow. Reading a newsletter should be reading, not spelunking.
struct NewsSummaryScreen: View {
    let item: UpToSpeedItem
    var isActive: Bool = true
    let onReachedBottom: (() -> Void)?
    var reserveTopSpace = true

    @Environment(AppModel.self) private var appModel
    @State private var showsFullArticle = false
    @State private var articleBody: String?
    @State private var isLoadingArticle = false
    @State private var articleError: String?

    private var news: NewsSummary? {
        if case .newsSummary(let n) = item.payload { return n }
        return nil
    }

    var body: some View {
        StoryScreenScaffold(
            flintByline: .init(meta: news.map { [Self.publication(for: $0), metaLine($0)].compactMap { $0 }.joined(separator: " · ") }),
            reserveTopSpace: reserveTopSpace,
            isActive: isActive,
            onReachedBottom: onReachedBottom
        ) {
            if let news {
                VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                    Text(news.title)
                        .font(SparkTypography.heroSmall)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    // The standfirst. It arrives wrapped in `**…**`, so markdown
                    // rendering is what gives it its weight — no card needed.
                    if let tldr = news.tldr {
                        SparkRichContentText(
                            text: tldr,
                            font: SparkTypography.body,
                            foregroundStyle: .primary,
                            lineSpacing: 6
                        )
                    }

                    if let keyTakeaways = news.keyTakeaways {
                        GlassCard {
                            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                                Text("Key points").font(SparkTypography.bodyStrong)
                                SparkLongFormContentView(
                                    text: keyTakeaways,
                                    tint: .domainKnowledge,
                                    paragraphFont: SparkTypography.body
                                )
                            }
                        }
                    }

                    if let summary = news.summary {
                        GlassCard {
                            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                                Text("Summary").font(SparkTypography.bodyStrong)
                                SparkRichContentText(
                                    text: summary,
                                    font: SparkTypography.body,
                                    foregroundStyle: .primary,
                                    lineSpacing: 6
                                )
                            }
                        }
                    }

                    fullArticleDisclosure

                    if let urlString = news.url, let url = URL(string: urlString) {
                        Link(destination: url) {
                            Label("Open source", systemImage: "arrow.up.right.square")
                                .font(SparkTypography.bodySmall)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Meta

    static func publication(for news: NewsSummary) -> String {
        if let host = news.url.flatMap({ URL(string: $0)?.host() })?.lowercased() {
            let names = ["economist.com": "The Economist", "ft.com": "Financial Times", "noemamag.com": "Noema"]
            for (domain, name) in names where host == domain || host.hasSuffix("." + domain) {
                return name
            }
            return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        }
        return news.source.lowercased() == "fetch" ? "News" : news.source.capitalized
    }

    /// When it arrived. The publication is already the scaffold's label, so
    /// repeating it here would just be the same word twice.
    private func metaLine(_ news: NewsSummary) -> String? {
        news.time?.formatted(.relative(presentation: .named))
    }

    // MARK: - Full article

    /// Inline rather than a sheet, and loaded only once it is opened — the body
    /// is a second and third request, which is not worth making for a card the
    /// reader may well swipe straight past.
    private var fullArticleDisclosure: some View {
        DisclosureGroup(isExpanded: $showsFullArticle) {
            Group {
                if isLoadingArticle {
                    HStack(spacing: SparkSpacing.sm) {
                        ProgressView()
                        Text("Loading article…")
                            .font(SparkTypography.bodySmall)
                            .foregroundStyle(.secondary)
                    }
                } else if let articleBody {
                    SparkLongFormContentView(text: articleBody, tint: .domainKnowledge)
                } else {
                    Text(articleError ?? "No full article text was returned for this item.")
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, SparkSpacing.md)
        } label: {
            Text(showsFullArticle ? "Hide full article" : "Full article")
                .font(SparkTypography.bodySmall)
                .foregroundStyle(Color.domainKnowledge)
        }
        .tint(Color.domainKnowledge)
        .task(id: showsFullArticle) {
            guard showsFullArticle, articleBody == nil else { return }
            // Clear a previous failure rather than guarding on it: collapsing
            // the disclosure cancels this task, and a cancellation recorded as
            // an error would lock the article shut for as long as the page
            // keeps its state.
            articleError = nil
            await loadArticle()
        }
    }

    private func loadArticle() async {
        isLoadingArticle = true
        defer { isLoadingArticle = false }

        do {
            let detail = try await appModel.apiClient.request(EventsEndpoint.detail(id: item.id))
            let objectID = detail.target?.id ?? detail.event.target?.id
            var objectDetail: ObjectDetail?
            if let objectID {
                do {
                    objectDetail = try await appModel.apiClient.request(ObjectsEndpoint.detail(id: objectID))
                } catch where error.isAPICancellation {
                    throw error
                } catch {
                    // The object is a fallback source for the body; the event's
                    // own content block usually carries it. Losing it is not
                    // worth failing the whole disclosure over.
                    objectDetail = nil
                }
            }

            if let body = Self.articleBodyContent(detail, objectDetail: objectDetail) {
                articleBody = body
            } else {
                articleError = "No full article text was returned for this item."
            }
        } catch where error.isAPICancellation {
            // The reader collapsed the disclosure or swiped away. Not a
            // failure, and recording it as one would block the next attempt.
        } catch {
            articleError = (error as? LocalizedError)?.errorDescription
                ?? "Could not load the full article."
        }
    }

    /// The article text, preferring the event's own content block, then the
    /// target object, then the event's target. Lifted unchanged from the sheet
    /// this disclosure replaced.
    static func articleBodyContent(_ detail: EventDetail, objectDetail: ObjectDetail?) -> String? {
        let service = detail.event.service

        if let block = detail.blocks.first(where: { block in
            !isRawBlock(block)
                && nonEmpty(block.content) != nil
                && (blockType(block, matches: "\(service)_content")
                    || blockType(block, matches: "content")
                    || block.blockType.lowercased().hasSuffix("_content"))
        }), let text = nonEmpty(block.content) {
            return text
        }

        if let text = nonEmpty(objectDetail?.object.content) {
            return text
        }

        return nonEmpty(detail.target?.content)
    }

    private static func isRawBlock(_ block: Block) -> Bool {
        block.blockType.localizedCaseInsensitiveContains("raw")
    }

    private static func blockType(_ block: Block, matches expected: String) -> Bool {
        block.blockType.caseInsensitiveCompare(expected) == .orderedSame
    }

    private static func nonEmpty(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
