import SparkKit
import SparkUI
import SwiftUI

struct KnowledgeItemDetailView: View {
    let event: Event
    @Environment(AppModel.self) private var appModel
    @Environment(\.openURL) private var openURL
    @State private var detailState: KnowledgeDetailState = .loading
    @State private var reprocessError: String?

    private var title: String { event.target?.title ?? event.displayName ?? event.action }

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
                        if !payload.eventDetail.tags.isEmpty {
                            TagChipRow(payload.eventDetail.tags.names)
                        }
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
        .ignoresSafeArea(edges: .top)
        .sparkAppBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sparkSubViewToolbar(
            shareItems: knowledgeShareItems,
            rawTitle: "Raw knowledge item",
            rawPayload: knowledgeRawPayload,
            refresh: { await loadDetail() },
            reprocess: { await reprocessKnowledgeEvent() }
        )
        .alert("Couldn't reprocess", isPresented: reprocessErrorBinding) {
            Button("OK", role: .cancel) {
                reprocessError = nil
            }
        } message: {
            Text(reprocessError ?? "Try again later.")
        }
        .task(id: event.id) {
            await loadDetail()
        }
    }

    private var knowledgeShareItems: [Any] {
        if let url = event.url.flatMap(URL.init) {
            return [url]
        }
        return ["Spark Knowledge: \(title)"]
    }

    private var knowledgeRawPayload: String? {
        guard case .loaded(let payload) = detailState else { return nil }
        return SparkPrettyJSON.string(for: payload.eventDetail)
            ?? SparkPrettyJSON.fallback(entity: "knowledge_item", id: event.id, title: title)
    }

    private var reprocessErrorBinding: Binding<Bool> {
        Binding(
            get: { reprocessError != nil },
            set: { if !$0 { reprocessError = nil } }
        )
    }

    // MARK: - Colour block hero

    private func hero(for payload: KnowledgeDetailPayload?) -> some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top

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
            .frame(height: 240 + topInset)
            .clipped()
            .offset(y: -topInset)
        }
        .frame(height: 240)
        .ignoresSafeArea(edges: .top)
    }

    private var fallbackHeroBackground: some View {
        Rectangle()
            .fill(Color.domainKnowledge)
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
        let summaryBlock = summaryBlock(service: service, blocks: blocks)
        let articleBody = articleBodyContent(payload: payload, service: service, blocks: blocks)

        if let summary = summaryText(payload: payload, summaryBlock: summaryBlock, articleBody: articleBody) {
            summaryCallout(summary)
        }

        if let articleBody {
            ArticleBodyView(text: articleBody.text)
        }

        ForEach(remainingBlocks(blocks, summaryBlock: summaryBlock, articleBody: articleBody)) { block in
            blockCard(block)
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

    @ViewBuilder
    private func blockCard(_ block: Block) -> some View {
        if isKeyTakeawaysBlock(block), let content = nonEmpty(block.content) {
            let bullets = takeawayBullets(from: content)
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
                                    RichContentText(text: bullet, font: SparkTypography.body, foregroundStyle: .primary)
                                }
                            }
                        }
                    }
                }
            }
        } else {
            GlassCard {
                VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                    GlassCardHeader(
                        icon: "square.stack.3d.up",
                        tint: .domainKnowledge,
                        title: displayTitle(for: block),
                        trailing: displayType(for: block)
                    )
                    if let content = nonEmpty(block.content) {
                        RichContentText(text: content, font: SparkTypography.body, foregroundStyle: .primary)
                    }
                    if let value = nonEmpty(block.value) {
                        Text([value, block.unit].compactMap(nonEmpty).joined(separator: " "))
                            .font(SparkTypography.bodyStrong)
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
    }

    private func summaryText(
        payload: KnowledgeDetailPayload,
        summaryBlock: Block?,
        articleBody: KnowledgeArticleBodyContent?
    ) -> String? {
        let candidates = [
            summaryBlock.flatMap { nonEmpty($0.content) },
            nonEmpty(payload.objectDetail?.aiSummary),
            nonEmpty(payload.eventDetail.aiSummary),
            nonEmpty(event.tldr),
            articleBody.flatMap { firstArticleParagraph($0.text) },
        ].compactMap { $0 }

        return candidates.first { !looksTruncated($0) } ?? candidates.first
    }

    private func summaryBlock(service: String, blocks: [Block]) -> Block? {
        blocks
            .filter { block in
                !isRawBlock(block)
                    && nonEmpty(block.content) != nil
                    && isSummaryBlock(block, service: service)
            }
            .sorted { lhs, rhs in
                summaryRank(lhs) > summaryRank(rhs)
            }
            .first
    }

    private func articleBodyContent(payload: KnowledgeDetailPayload, service: String, blocks: [Block]) -> KnowledgeArticleBodyContent? {
        if let block = blocks.first(where: { block in
            !isRawBlock(block)
                && nonEmpty(block.content) != nil
                && (blockType(block, matches: "\(service)_content")
                    || blockType(block, matches: "content")
                    || block.blockType.lowercased().hasSuffix("_content"))
        }), let text = nonEmpty(block.content) {
            return KnowledgeArticleBodyContent(text: text, blockID: block.id)
        }

        if let text = nonEmpty(payload.objectDetail?.object.content) {
            return KnowledgeArticleBodyContent(text: text, blockID: nil)
        }

        if let text = nonEmpty(payload.eventDetail.target?.content) {
            return KnowledgeArticleBodyContent(text: text, blockID: nil)
        }

        return nil
    }

    private func remainingBlocks(_ blocks: [Block], summaryBlock: Block?, articleBody: KnowledgeArticleBodyContent?) -> [Block] {
        blocks.filter { block in
            if isRawBlock(block) { return false }
            if block.id == summaryBlock?.id { return false }
            if block.id == articleBody?.blockID { return false }
            return nonEmpty(block.content) != nil || nonEmpty(block.value) != nil
        }
    }

    private func isRawBlock(_ block: Block) -> Bool {
        block.blockType.localizedCaseInsensitiveContains("raw")
    }

    private func isKeyTakeawaysBlock(_ block: Block) -> Bool {
        let type = block.blockType.lowercased()
        return type == "key_takeaways" || type.hasSuffix("_key_takeaways")
    }

    private func blockType(_ block: Block, matches expected: String) -> Bool {
        block.blockType.caseInsensitiveCompare(expected) == .orderedSame
    }

    private func isSummaryBlock(_ block: Block, service: String) -> Bool {
        let type = block.blockType.lowercased()
        return blockType(block, matches: "\(service)_summary_paragraph")
            || blockType(block, matches: "summary_paragraph")
            || blockType(block, matches: "paragraph_summary")
            || type.hasSuffix("_summary_paragraph")
            || type.contains("summary")
    }

    private func summaryRank(_ block: Block) -> Int {
        let content = nonEmpty(block.content) ?? ""
        let type = block.blockType.lowercased()
        let title = block.title.lowercased()
        var score = min(content.count, 2_000)

        if looksTruncated(content) {
            score -= 1_000
        }
        if type.contains("short") || title.contains("short") || type.contains("tldr") || title.contains("tldr") {
            score -= 500
        }
        if type.hasSuffix("_summary_paragraph") || type == "summary_paragraph" {
            score += 100
        }
        return score
    }

    private func displayTitle(for block: Block) -> String {
        nonEmpty(block.title) ?? displayType(for: block)
    }

    private func displayType(for block: Block) -> String {
        block.blockType
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private func nonEmpty(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private func looksTruncated(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasSuffix("...")
            || trimmed.hasSuffix("…")
    }

    private func firstArticleParagraph(_ text: String) -> String? {
        ArticleBlock.parse(text).compactMap { block in
            if case .paragraph(let paragraph) = block, !looksTruncated(paragraph) {
                return nonEmpty(paragraph)
            }
            return nil
        }.first
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

    private func reprocessKnowledgeEvent() async {
        do {
            _ = try await appModel.apiClient.request(EventsEndpoint.reprocessKnowledgeEvent(id: event.id))
            await loadDetail()
        } catch {
            SparkObservability.captureHandled(error)
            reprocessError = (error as? LocalizedError)?.errorDescription ?? "The item couldn't be reprocessed."
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
            .uppercased()
    }

    private func takeawayBullets(from content: String) -> [String] {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        for candidate in takeawayArrayCandidates(from: trimmed) {
            if let decoded = decodeTakeawayArray(candidate) {
                return decoded
            }
        }

        return trimmed
            .components(separatedBy: .newlines)
            .flatMap(splitInlineQuotedTakeaways)
            .map(stripBulletPrefix)
            .compactMap(nonEmpty)
    }

    private func takeawayArrayCandidates(from text: String) -> [String] {
        var candidates = [text]

        let unescaped = text
            .replacingOccurrences(of: #"\""#, with: #"""#)
            .replacingOccurrences(of: #"\/"#, with: "/")
        if unescaped != text {
            candidates.append(unescaped)
        }

        let baseCandidates = candidates
        for candidate in baseCandidates {
            if let start = candidate.firstIndex(of: "["),
               let end = candidate.lastIndex(of: "]"),
               start < end {
                let slice = String(candidate[start...end])
                if !candidates.contains(slice) {
                    candidates.append(slice)
                }
            }
        }

        return candidates
    }

    private func decodeTakeawayArray(_ text: String) -> [String]? {
        guard text.hasPrefix("["), text.hasSuffix("]"), let data = text.data(using: .utf8) else {
            return nil
        }

        guard let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return nil
        }

        let bullets = decoded
            .map(stripBulletPrefix)
            .compactMap(nonEmpty)
        return bullets.isEmpty ? nil : bullets
    }

    private func splitInlineQuotedTakeaways(_ line: String) -> [String] {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("[\""), trimmed.hasSuffix("\"]") else {
            return [trimmed]
        }

        let body = trimmed
            .dropFirst(2)
            .dropLast(2)
            .replacingOccurrences(of: #"\/"#, with: "/")
        return body
            .components(separatedBy: "\",\"")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private func stripBulletPrefix(_ line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["- ", "* ", "• "] {
            if trimmed.hasPrefix(prefix) {
                return String(trimmed.dropFirst(prefix.count))
            }
        }
        return trimmed
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

private struct KnowledgeArticleBodyContent {
    let text: String
    let blockID: String?
}
