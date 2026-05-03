import SparkKit
import SparkUI
import SwiftUI

struct KnowledgeItemDetailView: View {
    let event: Event
    @Environment(AppModel.self) private var appModel
    @Environment(\.openURL) private var openURL
    @State private var detailState: KnowledgeDetailState = .loading

    private var title: String { event.target?.title ?? event.action }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                switch detailState {
                case .loaded(let payload):
                    hero(for: payload)
                        .padding(.bottom, SparkSpacing.lg)
                default:
                    hero(for: nil)
                        .padding(.bottom, SparkSpacing.lg)
                }

                VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                    switch detailState {
                    case .loading:
                        headerSection(payload: nil)
                        LoadingShimmerCard()
                        LoadingShimmerCard()
                    case .loaded(let payload):
                        headerSection(payload: payload)
                        contentCards(for: payload)
                    case .error:
                        headerSection(payload: nil)
                        EmptyState(
                            systemImage: "exclamationmark.triangle",
                            title: "Couldn't load content",
                            message: "The full article analysis isn't available right now."
                        )
                    }

                    readOriginalButton
                }
                .padding(.horizontal, SparkSpacing.lg)
                .padding(.bottom, SparkSpacing.xl)
            }
        }
        .background(Color.sparkSurface.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task(id: event.id) {
            await loadDetail()
        }
    }

    // MARK: - Colour block hero

    private func hero(for payload: KnowledgeDetailPayload?) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let url = payload?.mainImageURL ?? mainImageURL(event: event) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        fallbackHeroBackground
                    }
                }
                .frame(height: 240)
                .clipped()
            } else {
                fallbackHeroBackground
            }

            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(.white.opacity(0.75))

                Text(sourceLabel(payload: payload))
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.white.opacity(0.9))
                    .textCase(.uppercase)
            }
            .padding(SparkSpacing.lg)
        }
    }

    private var fallbackHeroBackground: some View {
        Rectangle()
            .fill(Color.domainKnowledge)
            .frame(height: 240)
            .overlay {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 92, weight: .light))
                    .foregroundStyle(.white.opacity(0.32))
            }
    }

    // MARK: - Header

    private func headerSection(payload: KnowledgeDetailPayload?) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            HStack(spacing: SparkSpacing.xs) {
                Text(sourceLabel(payload: payload))
                    .font(SparkTypography.captionStrong)
                    .foregroundStyle(.secondary)
                if let time = event.time {
                    Text(" — ")
                        .foregroundStyle(.secondary)
                    Text(time.formatted(date: .abbreviated, time: .omitted))
                        .font(SparkTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(title)
                .font(SparkFonts.display(.title, weight: .bold))
        }
    }

    // MARK: - Content cards

    @ViewBuilder
    private func contentCards(for payload: KnowledgeDetailPayload) -> some View {
        let detail = payload.eventDetail
        let blocks = detail.blocks
        let service = detail.event.service

        if let summary = summaryText(payload: payload, service: service, blocks: blocks) {
            summaryCallout(summary)
        }

        let articleText = longerArticleContent(payload: payload, service: service, blocks: blocks)
        if let body = articleText, !body.isEmpty {
            ArticleBodyView(text: body)
        }

        if let takeaways = blockContent(service: service, kind: "key_takeaways", blocks: blocks) {
            let bullets = takeaways.components(separatedBy: "\n").filter { !$0.isEmpty }
            if !bullets.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                        GlassCardHeader(icon: "list.bullet", tint: .domainKnowledge, title: "Key Takeaways")
                        VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                            ForEach(bullets, id: \.self) { bullet in
                                HStack(alignment: .top, spacing: SparkSpacing.sm) {
                                    Image(systemName: "checkmark")
                                        .font(.caption2)
                                        .foregroundStyle(Color.domainKnowledge)
                                        .padding(.top, 3)
                                    Text(bullet)
                                        .font(SparkTypography.body)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
            }
        }

        if !detail.tags.isEmpty {
            TagChipRow(detail.tags)
        }
    }

    // MARK: - Summary callout

    private func summaryCallout(_ text: String) -> some View {
        GlassCard(tint: Color.domainKnowledge.opacity(0.08)) {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                GlassCardHeader(icon: "doc.text", tint: .domainKnowledge, title: "Summary")
                RichContentText(text: text, font: SparkTypography.body, foregroundStyle: .primary)
            }
        }
    }

    // MARK: - Read Original

    @ViewBuilder
    private var readOriginalButton: some View {
        if let urlString = event.url, let url = URL(string: urlString) {
            Button {
                openURL(url)
            } label: {
                HStack(spacing: SparkSpacing.sm) {
                    Image(systemName: "safari")
                    Text("Open Original ↗")
                        .font(SparkTypography.bodyStrong)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, SparkSpacing.md)
            }
            .sparkGlass(.capsule, tint: Color.domainKnowledge.opacity(0.12))
            .foregroundStyle(Color.domainKnowledge)
        }
    }

    // MARK: - Helpers

    private func summaryText(payload: KnowledgeDetailPayload, service: String, blocks: [Block]) -> String? {
        blockContent(service: service, kind: "paragraph_summary", blocks: blocks)
            ?? blockContent(service: service, kind: "summary_paragraph", blocks: blocks)
            ?? payload.objectDetail?.aiSummary
            ?? payload.eventDetail.aiSummary
            ?? event.tldr
    }

    private func longerArticleContent(payload: KnowledgeDetailPayload, service: String, blocks: [Block]) -> String? {
        let objectContent = payload.objectDetail?.object.content ?? payload.eventDetail.target?.content
        let fromBlock = blockContent(service: service, kind: "raw_content", blocks: blocks)
            ?? blockContent(service: service, kind: "fetch_content", blocks: blocks)
            ?? blockContent(service: service, kind: "article_body", blocks: blocks)
        let targetLen = objectContent?.count ?? 0
        let blockLen = fromBlock?.count ?? 0
        if targetLen == 0 && blockLen == 0 { return nil }
        return targetLen >= blockLen ? objectContent : fromBlock
    }

    private func blockContent(service: String, kind: String, blocks: [Block]) -> String? {
        let prefixed = "\(service)_\(kind)"
        return blocks.first { $0.blockType == prefixed }?.content
            ?? blocks.first { $0.blockType == kind }?.content
    }

    private func loadDetail() async {
        detailState = .loading
        do {
            let detail = try await appModel.apiClient.request(EventsEndpoint.detail(id: event.id))
            let objectID = detail.target?.id ?? event.target?.id
            let objectDetail: ObjectDetail?
            if let objectID {
                objectDetail = try? await appModel.apiClient.request(ObjectsEndpoint.detail(id: objectID))
            } else {
                objectDetail = nil
            }
            detailState = .loaded(KnowledgeDetailPayload(eventDetail: detail, objectDetail: objectDetail))
        } catch APIError.notModified {
            return
        } catch {
            SparkObservability.captureHandled(error)
            detailState = .error(String(describing: error))
        }
    }

    private func mainImageURL(event: Event) -> URL? {
        event.target?.mediaUrl.flatMap(URL.init(string:))
    }

    private func sourceLabel(payload: KnowledgeDetailPayload?) -> String {
        if let host = sourceHost(payload: payload) {
            return host
        }
        return payload?.eventDetail.actor?.title
            ?? event.actor?.title
            ?? event.service.capitalized
    }

    private func sourceHost(payload: KnowledgeDetailPayload?) -> String? {
        let raw = payload?.objectDetail?.object.url
            ?? payload?.eventDetail.event.url
            ?? event.url
        guard let raw,
              let host = URL(string: raw)?.host
        else { return nil }
        return host
            .replacingOccurrences(of: "www.", with: "")
            .split(separator: ".")
            .map { part in
                if part.count <= 3 {
                    return part.uppercased()
                }
                return part.prefix(1).uppercased() + part.dropFirst().lowercased()
            }
            .joined(separator: ".")
    }
}

// MARK: - Article body renderer

private struct ArticleBodyView: View {
    let text: String

    private var blocks: [ArticleBlock] {
        ArticleBlock.parse(text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.lg) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .heading(let text, let level):
                    RichContentText(
                        text: text,
                        font: level == 1
                            ? SparkFonts.display(.title2, weight: .bold)
                            : SparkFonts.display(.title3, weight: .bold),
                        foregroundStyle: .primary,
                        lineSpacing: 2
                    )
                    .padding(.top, level == 1 ? SparkSpacing.sm : SparkSpacing.xs)

                case .paragraph(let text):
                    RichContentText(
                        text: text,
                        font: SparkTypography.body,
                        foregroundStyle: .primary,
                        lineSpacing: 6
                    )

                case .quote(let text):
                    HStack(alignment: .top, spacing: SparkSpacing.md) {
                        Rectangle()
                            .fill(Color.domainKnowledge)
                            .frame(width: 3)
                            .clipShape(.capsule)
                        RichContentText(
                            text: text,
                            font: SparkTypography.body,
                            foregroundStyle: .secondary,
                            lineSpacing: 6
                        )
                        .italic()
                    }

                case .bullets(let bullets):
                    VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                        ForEach(bullets, id: \.self) { bullet in
                            HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.sm) {
                                Text("•")
                                    .font(SparkTypography.bodyStrong)
                                    .foregroundStyle(Color.domainKnowledge)
                                RichContentText(
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
        }
        .padding(.horizontal, SparkSpacing.xs)
    }
}

private enum ArticleBlock {
    case heading(String, level: Int)
    case paragraph(String)
    case quote(String)
    case bullets([String])

    static func parse(_ text: String) -> [ArticleBlock] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return [] }

        let rawBlocks = normalized.components(separatedBy: "\n\n")
        var output: [ArticleBlock] = []

        for rawBlock in rawBlocks {
            let trimmed = rawBlock.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let lines = trimmed
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            guard !lines.isEmpty else { continue }

            if lines.count == 1, let heading = heading(from: lines[0]) {
                output.append(.heading(heading.text, level: heading.level))
                continue
            }

            if lines.allSatisfy({ $0.hasPrefix(">") }) {
                let text = lines
                    .map { String($0.drop(while: { $0 == ">" || $0 == " " })) }
                    .joined(separator: "\n")
                output.append(.quote(text))
                continue
            }

            if lines.allSatisfy(isBulletLine) {
                output.append(.bullets(lines.map(stripBulletPrefix)))
                continue
            }

            output.append(.paragraph(lines.joined(separator: "\n")))
        }

        return output
    }

    private static func heading(from line: String) -> (text: String, level: Int)? {
        if line.hasPrefix("### ") {
            return (String(line.dropFirst(4)), 3)
        }
        if line.hasPrefix("## ") {
            return (String(line.dropFirst(3)), 2)
        }
        if line.hasPrefix("# ") {
            return (String(line.dropFirst(2)), 1)
        }
        return nil
    }

    private static func isBulletLine(_ line: String) -> Bool {
        line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ")
    }

    private static func stripBulletPrefix(_ line: String) -> String {
        if isBulletLine(line) {
            return String(line.dropFirst(2))
        }
        return line
    }
}

private enum KnowledgeDetailState {
    case loading
    case loaded(KnowledgeDetailPayload)
    case error(String)
}

private struct KnowledgeDetailPayload {
    let eventDetail: EventDetail
    let objectDetail: ObjectDetail?

    var mainImageURL: URL? {
        eventDetail.target?.mediaUrl.flatMap(URL.init(string:))
            ?? objectDetail?.object.mediaUrl.flatMap(URL.init(string:))
            ?? eventDetail.event.target?.mediaUrl.flatMap(URL.init(string:))
    }
}
