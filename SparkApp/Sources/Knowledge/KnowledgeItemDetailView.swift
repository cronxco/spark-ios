import SparkKit
import SparkUI
import SwiftUI

struct KnowledgeItemDetailView: View {
    let event: Event
    @Environment(AppModel.self) private var appModel
    @Environment(\.openURL) private var openURL
    @State private var detailState: DetailLoadState<EventDetail> = .loading

    private var imageUrl: URL? {
        guard let raw = event.target?.mediaUrl else { return nil }
        return URL(string: raw)
    }

    private var title: String { event.target?.title ?? event.action }
    private var source: String { event.actor?.title ?? event.service }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                heroImage
                VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                    headerSection
                    switch detailState {
                    case .loading:
                        LoadingShimmerCard()
                        LoadingShimmerCard()
                    case .loaded(let detail):
                        contentCards(for: detail)
                    case .error:
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

    // MARK: - Hero image

    @ViewBuilder
    private var heroImage: some View {
        if let url = imageUrl {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Color.sparkElevated
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .clipped()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            HStack(spacing: SparkSpacing.xs) {
                Text(source)
                    .font(SparkTypography.captionStrong)
                    .foregroundStyle(.secondary)
                if let time = event.time {
                    Text("·")
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
    private func contentCards(for detail: EventDetail) -> some View {
        let blocks = detail.blocks
        let service = event.service

        if let tldrText = blockContent(service: service, kind: "tldr", blocks: blocks) ?? event.tldr {
            GlassCard(tint: Color.domainKnowledge.opacity(0.08)) {
                VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                    GlassCardHeader(icon: "text.quote", tint: .domainKnowledge, title: "TL;DR")
                    Text(tldrText)
                        .font(SparkTypography.body)
                        .italic()
                        .foregroundStyle(.primary)
                }
            }
        }

        if let summary = blockContent(service: service, kind: "summary_paragraph", blocks: blocks) {
            GlassCard {
                VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                    GlassCardHeader(icon: "doc.text", tint: .domainKnowledge, title: "Summary")
                    Text(summary)
                        .font(SparkTypography.body)
                        .foregroundStyle(.primary)
                }
            }
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
                                    Text("·")
                                        .font(SparkTypography.bodyStrong)
                                        .foregroundStyle(Color.domainKnowledge)
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

    // MARK: - Read Original

    @ViewBuilder
    private var readOriginalButton: some View {
        if let urlString = event.url, let url = URL(string: urlString) {
            Button {
                openURL(url)
            } label: {
                HStack(spacing: SparkSpacing.sm) {
                    Image(systemName: "safari")
                    Text("Read Original")
                        .font(SparkTypography.bodyStrong)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, SparkSpacing.md)
            }
            .sparkGlass(.capsule, tint: Color.domainKnowledge.opacity(0.15))
            .foregroundStyle(Color.domainKnowledge)
        }
    }

    // MARK: - Helpers

    private func blockContent(service: String, kind: String, blocks: [Block]) -> String? {
        let prefixed = "\(service)_\(kind)"
        return blocks.first { $0.blockType == prefixed }?.content
            ?? blocks.first { $0.blockType == kind }?.content
    }

    private func loadDetail() async {
        detailState = .loading
        do {
            let detail = try await appModel.apiClient.request(EventsEndpoint.detail(id: event.id))
            detailState = .loaded(detail)
        } catch APIError.notModified {
            return
        } catch {
            SparkObservability.captureHandled(error)
            detailState = .error(String(describing: error))
        }
    }
}
