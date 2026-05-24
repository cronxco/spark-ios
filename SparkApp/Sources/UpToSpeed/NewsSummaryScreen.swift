import SparkKit
import SparkUI
import SwiftUI

/// Renders a news_summary Up to Speed item as stacked glass cards —
/// TL;DR, paragraph summary, and key points all visible at once.
/// Card style matches KnowledgeItemDetailView using the domainKnowledge tint.
struct NewsSummaryScreen: View {
    let item: UpToSpeedItem
    let viewModel: UpToSpeedViewModel

    @Environment(AppModel.self) private var appModel
    @State private var showFullArticle = false

    private var news: NewsSummary? {
        if case .newsSummary(let n) = item.payload { return n }
        return nil
    }

    var body: some View {
        StoryScreenScaffold(label: news.map { $0.source.uppercased() }) {
            if let news {
                VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                    Text(news.title)
                        .font(SparkTypography.heroSmall)
                        .foregroundStyle(.primary)

                    if let tldr = news.tldr {
                        GlassCard(tint: Color.domainKnowledge.opacity(0.1)) {
                            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                                GlassCardHeader(icon: "bolt.fill", tint: .domainKnowledge, title: "TL;DR")
                                SparkRichContentText(
                                    text: tldr,
                                    font: SparkTypography.body,
                                    foregroundStyle: .primary,
                                    lineSpacing: 5
                                )
                            }
                        }
                    }

                    if let summary = news.summary {
                        GlassCard(tint: Color.domainKnowledge.opacity(0.06)) {
                            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                                GlassCardHeader(icon: "doc.text", tint: .domainKnowledge, title: "Summary")
                                SparkRichContentText(
                                    text: summary,
                                    font: SparkTypography.body,
                                    foregroundStyle: .primary,
                                    lineSpacing: 5
                                )
                            }
                        }
                    }

                    if let keyTakeaways = news.keyTakeaways {
                        GlassCard(tint: Color.domainKnowledge.opacity(0.06)) {
                            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                                GlassCardHeader(icon: "list.bullet", tint: .domainKnowledge, title: "Key Points")
                                keyPointsContent(from: keyTakeaways)
                            }
                        }
                    }

                    Button {
                        showFullArticle = true
                    } label: {
                        Label("Read full article", systemImage: "doc.text.magnifyingglass")
                            .font(SparkTypography.bodyStrong)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, SparkSpacing.md)
                    }
                    .sparkGlass(.capsule, tint: Color.domainKnowledge.opacity(0.12))
                    .foregroundStyle(Color.domainKnowledge)
                    .buttonStyle(.plain)

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
        .sheet(isPresented: $showFullArticle) {
            if let news {
                FullArticleSheet(
                    title: news.title,
                    url: news.url,
                    apiClient: appModel.apiClient,
                    eventID: item.id
                )
            }
        }
    }

    // MARK: - Key points rendering

    @ViewBuilder
    private func keyPointsContent(from text: String) -> some View {
        let bullets = parseBullets(from: text)
        if bullets.isEmpty {
            SparkRichContentText(
                text: text,
                font: SparkTypography.body,
                foregroundStyle: .primary,
                lineSpacing: 5
            )
        } else {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                ForEach(bullets, id: \.self) { bullet in
                    HStack(alignment: .top, spacing: SparkSpacing.sm) {
                        Image(systemName: "checkmark")
                            .font(.caption2)
                            .foregroundStyle(Color.domainKnowledge)
                            .padding(.top, 3)
                        SparkRichContentText(
                            text: bullet,
                            font: SparkTypography.body,
                            foregroundStyle: .primary,
                            lineSpacing: 5
                        )
                    }
                }
            }
        }
    }

    // MARK: - Bullet parsing (ported from KnowledgeItemDetailView)

    private func parseBullets(from content: String) -> [String] {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        for candidate in arrayCandidates(from: trimmed) {
            if let decoded = decodeArray(candidate) {
                return decoded
            }
        }

        return trimmed
            .components(separatedBy: .newlines)
            .flatMap(splitInlineItems)
            .map(stripBulletPrefix)
            .compactMap(nonEmptyTrimmed)
    }

    private func arrayCandidates(from text: String) -> [String] {
        var candidates = [text]
        let unescaped = text
            .replacingOccurrences(of: #"\""#, with: #"""#)
            .replacingOccurrences(of: #"\/"#, with: "/")
        if unescaped != text { candidates.append(unescaped) }
        for candidate in candidates {
            if let start = candidate.firstIndex(of: "["),
               let end = candidate.lastIndex(of: "]"),
               start < end {
                let slice = String(candidate[start...end])
                if !candidates.contains(slice) { candidates.append(slice) }
            }
        }
        return candidates
    }

    private func decodeArray(_ text: String) -> [String]? {
        guard text.hasPrefix("["), text.hasSuffix("]"),
              let data = text.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data)
        else { return nil }
        let bullets = decoded.map(stripBulletPrefix).compactMap(nonEmptyTrimmed)
        return bullets.isEmpty ? nil : bullets
    }

    private func splitInlineItems(_ line: String) -> [String] {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("[\""), trimmed.hasSuffix("\"]") else { return [trimmed] }
        let body = trimmed.dropFirst(2).dropLast(2)
            .replacingOccurrences(of: #"\/"#, with: "/")
        return body
            .components(separatedBy: "\",\"")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private func stripBulletPrefix(_ line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["- ", "* ", "• "] {
            if trimmed.hasPrefix(prefix) { return String(trimmed.dropFirst(prefix.count)) }
        }
        return trimmed
    }

    private func nonEmptyTrimmed(_ text: String?) -> String? {
        guard let t = text?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        return t
    }
}

// MARK: - FullArticleSheet

/// Sheet that renders the full article content from the event's blocks.
struct FullArticleSheet: View {
    let title: String
    let url: String?
    let apiClient: APIClient
    let eventID: String

    @Environment(\.dismiss) private var dismiss
    @State private var detail: EventDetail?
    @State private var objectDetail: ObjectDetail?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading article…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let detail {
                    eventContent(detail)
                } else {
                    ContentUnavailableView(
                        "Article Unavailable",
                        systemImage: "doc.text",
                        description: Text(errorMessage ?? "Could not load the full article.")
                    )
                }
            }
            .background(SparkResolvedAppBackground().ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if let urlString = url, let url = URL(string: urlString) {
                    ToolbarItem(placement: .primaryAction) {
                        Link(destination: url) {
                            Image(systemName: "safari")
                        }
                    }
                }
            }
        }
        .task { await loadEvent() }
    }

    private func eventContent(_ detail: EventDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                if let body = articleBodyContent(detail) {
                    SparkLongFormContentView(text: body, tint: .domainKnowledge)
                } else {
                    ContentUnavailableView(
                        "Article Unavailable",
                        systemImage: "doc.text",
                        description: Text("No full article text was returned for this item.")
                    )
                }
            }
            .padding(SparkSpacing.lg)
        }
        .scrollContentBackground(.hidden)
    }

    private func loadEvent() async {
        isLoading = true
        errorMessage = nil
        do {
            let eventDetail = try await apiClient.request(EventsEndpoint.detail(id: eventID))
            detail = eventDetail
            let objectID = eventDetail.target?.id ?? eventDetail.event.target?.id
            if let objectID {
                objectDetail = try? await apiClient.request(ObjectsEndpoint.detail(id: objectID))
            } else {
                objectDetail = nil
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Could not load the full article."
        }
        isLoading = false
    }

    private func articleBodyContent(_ detail: EventDetail) -> String? {
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

        if let text = nonEmpty(detail.target?.content) {
            return text
        }

        return nil
    }

    private func isRawBlock(_ block: Block) -> Bool {
        block.blockType.localizedCaseInsensitiveContains("raw")
    }

    private func blockType(_ block: Block, matches expected: String) -> Bool {
        block.blockType.caseInsensitiveCompare(expected) == .orderedSame
    }

    private func nonEmpty(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
