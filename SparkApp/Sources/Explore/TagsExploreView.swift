import SparkKit
import SparkUI
import SwiftUI

@MainActor
@Observable
private final class TagsExploreViewModel {
    private(set) var tags: [Tag] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var errorMessage: String?
    private var nextCursor: String?
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func load(query: String = "") async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let page = try await apiClient.request(TagsEndpoint.index(query: query))
            tags = page.data
            nextCursor = page.nextCursor
        } catch APIError.notModified {
            return
        } catch {
            SparkObservability.captureHandled(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Couldn't load tags."
        }
    }

    func loadMore(query: String = "") async {
        guard let nextCursor, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let page = try await apiClient.request(
                TagsEndpoint.index(query: query, cursor: nextCursor)
            )
            tags.append(contentsOf: page.data.filter { tag in
                !tags.contains(where: { $0.id == tag.id })
            })
            self.nextCursor = page.nextCursor
        } catch {
            SparkObservability.captureHandled(error)
        }
    }

    var hasMore: Bool {
        nextCursor != nil
    }
}

struct TagsExploreView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: TagsExploreViewModel?
    @State private var path: [DetailRoute] = []
    @State private var query = ""

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: SparkSpacing.md) {
                    SparkMainPageHeader(
                        title: "Tags",
                        subtitle: "Browse everything you've grouped across Spark"
                    )
                    .padding(.bottom, SparkSpacing.sm)

                    content
                }
                .padding(.horizontal, SparkSpacing.lg)
                .padding(.top, SparkSpacing.md)
                .padding(.bottom, SparkSpacing.xl)
            }
            .sparkAppBackground()
            .sparkScrollingNavigationBar()
            .sparkMainNavigationTitle("Tags")
            .sparkDetailDestinations()
            .sparkMainAppToolbar()
            .refreshable {
                await viewModel?.load(query: query)
            }
        }
        .searchable(text: $query, prompt: "Search tags")
        .task {
            if viewModel == nil {
                viewModel = TagsExploreViewModel(apiClient: appModel.apiClient)
            }
            await viewModel?.load()
        }
        .task(id: query) {
            guard let viewModel else { return }
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            await viewModel.load(query: query)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let viewModel {
            if viewModel.isLoading && viewModel.tags.isEmpty {
                LoadingShimmerCard()
                LoadingShimmerCard()
                LoadingShimmerCard()
            } else if let errorMessage = viewModel.errorMessage, viewModel.tags.isEmpty {
                EmptyState(
                    systemImage: "exclamationmark.triangle.fill",
                    title: "Couldn't load tags",
                    message: errorMessage,
                    actionTitle: "Retry"
                ) {
                    Task { await viewModel.load(query: query) }
                }
            } else if viewModel.tags.isEmpty {
                EmptyState(
                    systemImage: "tag",
                    title: query.isEmpty ? "No tags yet" : "No matching tags",
                    message: query.isEmpty
                        ? "Tags you add to events and objects will appear here."
                        : "Try a shorter search."
                )
            } else {
                ForEach(viewModel.tags) { tag in
                    NavigationLink(
                        value: DetailRoute.tag(id: tag.id, name: tag.name, type: tag.type)
                    ) {
                        tagRow(tag)
                    }
                    .buttonStyle(.plain)
                    .task {
                        if tag.id == viewModel.tags.last?.id, viewModel.hasMore {
                            await viewModel.loadMore(query: query)
                        }
                    }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SparkSpacing.sm)
                }
            }
        }
    }

    private func tagRow(_ tag: Tag) -> some View {
        let eventTag = tag.eventTag
        return GlassCard(radius: SparkRadii.lg, padding: SparkSpacing.md) {
            HStack(spacing: SparkSpacing.md) {
                DomainGlyph(icon: "tag.fill", tint: eventTag.tagTint, size: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(tag.name)
                        .font(SparkTypography.bodyStrong)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(tagSubtitle(tag))
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Text("\(tag.totalCount)")
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(eventTag.tagTint)

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func tagSubtitle(_ tag: Tag) -> String {
        let type = tag.eventTag.tagTypeLabel
            ?? tag.type?.replacingOccurrences(of: "_", with: " ").capitalized
            ?? "Tag"
        return "\(type) · \(tag.eventsCount) events · \(tag.objectsCount) objects"
    }
}
