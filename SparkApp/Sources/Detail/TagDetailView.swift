import SparkKit
import SparkUI
import SwiftUI

struct TagDetailView: View {
    let tagName: String
    let tagType: String?

    @Environment(AppModel.self) private var appModel
    @State private var results: [SearchResult] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

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
        .task(id: tagName) {
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

                if !isLoading, !results.isEmpty {
                    Text("\(results.count) item\(results.count == 1 ? "" : "s")")
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
                    if let route = detailRoute(for: result) {
                        NavigationLink(value: route) {
                            SearchResultRow(result: result)
                        }
                        .buttonStyle(.plain)
                    } else {
                        SearchResultRow(result: result)
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
        case .tag(let h): .tag(name: h.name, type: h.type)
        case .intent: nil
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await appModel.apiClient.request(
                SearchEndpoint.query(text: tagName)
            )
            results = response.results.filter(\.isTagDetailItem)
        } catch APIError.notModified {
            // No change — keep existing results
        } catch {
            SparkObservability.captureHandled(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Couldn't load items for this tag."
        }
        isLoading = false
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
            if let response = try? await appModel.apiClient.request(
                SearchEndpoint.query(text: tag.name)
            ) {
                previewResults = response.results.filter(\.isTagDetailItem)
            }
            loaded = true
        }
    }
}

private extension SearchResult {
    var isTagDetailItem: Bool {
        if case .tag = self { return false }
        return true
    }
}
