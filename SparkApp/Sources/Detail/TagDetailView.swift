import SparkKit
import SparkUI
import SwiftUI

struct TagDetailView: View {
    let tagID: String?
    let tagName: String
    let tagType: String?

    @Environment(AppModel.self) private var appModel
    @State private var results: [TagDetailItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var resolvedTagID: String?
    @State private var nextCursor: String?
    @State private var hasMore = false
    @State private var serverTotal: Int?
    @State private var isLoadingMore = false
    @State private var loadMoreError: String?

    init(tagID: String? = nil, tagName: String, tagType: String?) {
        self.tagID = tagID
        self.tagName = tagName
        self.tagType = tagType
    }

    private var tag: EventTag { EventTag(name: tagName, type: tagType) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                headerSection
                resultsSection
            }
            .padding(.horizontal, SparkSpacing.lg)
            .padding(.top, SparkSpacing.xxl)
            .padding(.bottom, SparkSpacing.xl)
        }
        .sparkAppBackground()
        .navigationBarTitleDisplayMode(.inline)
        .task(id: tagID ?? "\(tagType ?? ""):\(tagName)") {
            await load()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            Text(tagName)
                .font(SparkFonts.display(.largeTitle, weight: .bold))
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: SparkSpacing.sm) {
                if let label = tag.tagTypeLabel {
                    Text(label)
                        .font(SparkTypography.captionStrong)
                        .foregroundStyle(tag.tagTint)
                        .padding(.horizontal, SparkSpacing.md - 2)
                        .padding(.vertical, SparkSpacing.xs + 1)
                        .sparkGlass(.capsule, tint: tag.tagTint.opacity(0.15))
                }

                if !isLoading, let serverTotal {
                    Text("\(serverTotal) item\(serverTotal == 1 ? "" : "s")")
                        .font(SparkTypography.captionStrong)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Results

    @ViewBuilder
    private var resultsSection: some View {
        if isLoading {
            LoadingShimmerCard()
            LoadingShimmerCard()
            LoadingShimmerCard()
        } else if let errorMessage {
            EmptyState(
                systemImage: "exclamationmark.triangle.fill",
                title: "Couldn't load",
                message: errorMessage,
                actionTitle: "Retry"
            ) { Task { await load() } }
        } else if results.isEmpty {
            EmptyState(
                systemImage: "tag",
                title: "No items tagged",
                message: "Nothing tagged \"\(tagName)\" yet."
            )
        } else {
            LazyVStack(spacing: SparkSpacing.sm) {
                ForEach(results) { result in
                    NavigationLink(value: detailRoute(for: result)) {
                        TagDetailItemRow(item: result)
                    }
                    .buttonStyle(.plain)
                }
                if hasMore {
                    if isLoadingMore {
                        ProgressView().frame(maxWidth: .infinity)
                    } else if let loadMoreError {
                        VStack(spacing: SparkSpacing.sm) {
                            Text(loadMoreError).font(SparkTypography.bodySmall).foregroundStyle(.secondary)
                            Button("Retry") { Task { await loadMore() } }.buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Button("Load more") { Task { await loadMore() } }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func detailRoute(for result: TagDetailItem) -> DetailRoute {
        switch result.kind {
        case .event: .event(id: result.id)
        case .object: .object(id: result.id)
        case .block: .block(id: result.id)
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        loadMoreError = nil
        do {
            let id: String
            if let tagID {
                id = tagID
            } else {
                let list = try await appModel.apiClient.request(TagsEndpoint.list(query: tagName))
                guard let match = list.data.first(where: { $0.name == tagName && $0.type == tagType }) else {
                    results = []
                    isLoading = false
                    return
                }
                id = match.id
            }
            let page = try await appModel.apiClient.request(TagsEndpoint.detail(id: id))
            resolvedTagID = id
            serverTotal = page.tag.totalCount
            results = page.data
            nextCursor = page.nextCursor
            hasMore = page.hasMore
        } catch APIError.notModified {
            // No change — keep existing results
        } catch {
            SparkObservability.captureHandled(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Couldn't load items for this tag."
        }
        isLoading = false
    }

    private func loadMore() async {
        guard let resolvedTagID, let nextCursor else { return }
        isLoadingMore = true
        loadMoreError = nil
        defer { isLoadingMore = false }
        do {
            let page = try await appModel.apiClient.request(TagsEndpoint.detail(id: resolvedTagID, cursor: nextCursor))
            results.append(contentsOf: page.data)
            self.nextCursor = page.nextCursor
            hasMore = page.hasMore
        } catch {
            SparkObservability.captureHandled(error)
            loadMoreError = (error as? LocalizedError)?.errorDescription ?? "Couldn't load more tagged items."
        }
    }
}

private struct TagDetailItemRow: View {
    let item: TagDetailItem

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.xs) {
            Text(item.title).font(SparkTypography.bodyStrong)
            if let subtitle = item.subtitle {
                Text(subtitle).font(SparkTypography.bodySmall).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SparkSpacing.md)
        .sparkGlass(.roundedRect(SparkRadii.md))
    }
}

// MARK: - Preview card for long-press peek

/// Compact tag identity card shown in context-menu previews.
struct TagPreviewCard: View {
    let tag: EventTag

    @Environment(AppModel.self) private var appModel
    @State private var previewResults: [TagDetailItem] = []
    @State private var previewTotal = 0
    @State private var loaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                Text(tag.name)
                    .font(SparkFonts.display(.title2, weight: .bold))
                    .foregroundStyle(.primary)

                if let label = tag.tagTypeLabel {
                    Text(label)
                        .font(SparkTypography.captionStrong)
                        .foregroundStyle(tag.tagTint)
                        .padding(.horizontal, SparkSpacing.sm)
                        .padding(.vertical, 3)
                        .sparkGlass(.capsule, tint: tag.tagTint.opacity(0.15))
                }
            }

            if loaded {
                if previewResults.isEmpty {
                    Text("No items tagged yet.")
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                        ForEach(previewResults.prefix(3)) { result in
                            HStack(spacing: SparkSpacing.sm) {
                                Circle()
                                    .fill(tag.tagTint.opacity(0.3))
                                    .frame(width: 6, height: 6)
                                Text(result.title)
                                    .font(SparkTypography.bodySmall)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                            }
                        }

                        if previewTotal > previewResults.count {
                            Text("+\(previewTotal - previewResults.count) more")
                                .font(SparkTypography.captionStrong)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                HStack(spacing: SparkSpacing.sm) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Loading…")
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(SparkSpacing.lg)
        .frame(width: 260, alignment: .leading)
        .sparkAppBackground()
        .task(id: tag.name) {
            guard !loaded else { return }
            let id: String?
            if let tagID = tag.tagID {
                id = tagID
            } else if let page = try? await appModel.apiClient.request(TagsEndpoint.list(query: tag.name)) {
                id = page.data.first(where: { $0.name == tag.name && $0.type == tag.type })?.id
            } else {
                id = nil
            }
            if let id, let page = try? await appModel.apiClient.request(TagsEndpoint.detail(id: id, limit: 3)) {
                previewResults = page.data
                previewTotal = page.tag.totalCount
            }
            loaded = true
        }
    }
}
