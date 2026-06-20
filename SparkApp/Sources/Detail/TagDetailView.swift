import SparkKit
import SparkUI
import SwiftUI

struct TagDetailView: View {
    let tagID: String?
    let tagName: String
    let tagType: String?

    @Environment(AppModel.self) private var appModel
    @State private var results: [SearchResult] = []
    @State private var resolvedTag: Tag?
    @State private var nextCursor: String?
    @State private var isLoadingMore = false
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var tag: EventTag {
        resolvedTag?.eventTag ?? EventTag(id: tagID, name: tagName, type: tagType)
    }

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
        .sparkScrollingNavigationBar()
        .navigationBarTitleDisplayMode(.inline)
        .task(id: "\(tagID ?? ""):\(tagType ?? ""):\(tagName)") {
            await load()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            Text(tag.name)
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

                if !isLoading {
                    let count = resolvedTag?.totalCount ?? results.count
                    Text("\(count) item\(count == 1 ? "" : "s")")
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
                message: "Nothing tagged \"\(tag.name)\" yet."
            )
        } else {
            LazyVStack(spacing: SparkSpacing.sm) {
                ForEach(results) { result in
                    if let route = detailRoute(for: result) {
                        NavigationLink(value: route) {
                            SearchResultRow(result: result)
                        }
                        .buttonStyle(.plain)
                    } else {
                        SearchResultRow(result: result)
                    }
                }

                if nextCursor != nil {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SparkSpacing.md)
                        .task {
                            await loadMore()
                        }
                }
            }
        }
    }

    // MARK: - Helpers

    private func detailRoute(for result: SearchResult) -> DetailRoute? {
        switch result {
        case .event(let h): .event(id: h.id)
        case .object(let h): .object(id: h.id)
        case .block(let h): .block(id: h.id)
        case .metric(let h): .metric(identifier: h.identifier)
        case .integration(let h): .integration(service: h.id)
        case .place(let h): .place(id: h.id)
        case .tag(let h): .tag(id: h.id, name: h.name, type: h.type)
        case .intent: nil
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let id = try await resolveTagID()
            let response = try await appModel.apiClient.request(TagsEndpoint.detail(id: id))
            resolvedTag = response.tag
            results = response.data
            nextCursor = response.nextCursor
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
        guard let id = resolvedTag?.id ?? tagID,
              let cursor = nextCursor,
              !isLoadingMore
        else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let response = try await appModel.apiClient.request(
                TagsEndpoint.detail(id: id, cursor: cursor)
            )
            results.append(contentsOf: response.data.filter { item in
                !results.contains(where: { $0.id == item.id })
            })
            nextCursor = response.nextCursor
        } catch {
            SparkObservability.captureHandled(error)
        }
    }

    private func resolveTagID() async throws -> String {
        if let tagID {
            return tagID
        }

        let response = try await appModel.apiClient.request(
            TagsEndpoint.suggest(query: tagName, limit: 20)
        )
        guard let match = response.data.first(where: {
            $0.name.caseInsensitiveCompare(tagName) == .orderedSame
                && (tagType == nil || $0.type == tagType)
        }) else {
            throw TagDetailError.notFound
        }
        resolvedTag = match
        return match.id
    }
}

// MARK: - Preview card for long-press peek

/// Compact tag identity card shown in context-menu previews.
struct TagPreviewCard: View {
    let tag: EventTag

    @Environment(AppModel.self) private var appModel
    @State private var previewResults: [SearchResult] = []
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

                        if previewResults.count > 3 {
                            Text("+\(previewResults.count - 3) more")
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
            var resolvedID = tag.serverID
            if resolvedID == nil,
               let suggestions = try? await appModel.apiClient.request(
                   TagsEndpoint.suggest(query: tag.name, limit: 10)
               ) {
                resolvedID = suggestions.data.first(where: {
                    $0.name.caseInsensitiveCompare(tag.name) == .orderedSame
                        && (tag.type == nil || $0.type == tag.type)
                })?.id
            }
            if let resolvedID,
               let response = try? await appModel.apiClient.request(
                   TagsEndpoint.detail(id: resolvedID, limit: 4)
               ) {
                previewResults = response.data
            }
            loaded = true
        }
    }
}

private enum TagDetailError: LocalizedError {
    case notFound

    var errorDescription: String? {
        "This tag could not be found."
    }
}
