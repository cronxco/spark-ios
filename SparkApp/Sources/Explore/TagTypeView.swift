import Observation
import SparkKit
import SparkUI
import SwiftUI

@MainActor
@Observable
final class TagTypeViewModel {
    let type: String
    private let apiClient: APIClient

    private(set) var tags: [TagResource] = []
    /// How many tags of this type there are, from the first page's totals.
    private(set) var tagsCount: Int?
    private(set) var nextCursor: String?
    private(set) var hasMore = false
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var error: String?
    private var requestGeneration = 0

    init(type: String, apiClient: APIClient) {
        self.type = type
        self.apiClient = apiClient
    }

    /// The type's tags, most used first. `reset: false` loads the next page.
    func load(query: String?, reset: Bool = true) async {
        if !reset, isLoading || !hasMore { return }
        requestGeneration += 1
        let generation = requestGeneration
        isLoading = true
        defer {
            if generation == requestGeneration { isLoading = false }
        }
        do {
            let page = try await apiClient.request(
                TagsEndpoint.list(query: query, type: type, cursor: reset ? nil : nextCursor)
            )
            guard generation == requestGeneration, !Task.isCancelled else { return }
            tags = reset ? page.data : tags + page.data
            nextCursor = page.nextCursor
            hasMore = page.hasMore
            if query == nil, let total = page.types?.first(where: { $0.type == type }) {
                tagsCount = total.tagsCount
            }
            hasLoaded = true
            error = nil
        } catch APIError.notModified {
            hasLoaded = true
        } catch {
            guard generation == requestGeneration, !Task.isCancelled else { return }
            SparkObservability.captureHandled(error)
            self.error = TagsExploreViewModel.message(for: error)
        }
    }
}

/// See all for one tag type: every tag of it as rows with their uses, most
/// used first, with search. Pushed from a type's section in Explore's Tags.
struct TagTypeView: View {
    let type: String

    @Environment(AppModel.self) private var appModel
    @State private var viewModel: TagTypeViewModel?
    @State private var query = ""

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var title: String { TagTypeName.plural(type) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                TagSearchField(prompt: "Find \(title.lowercased())", text: $query)
                if let error = viewModel?.error {
                    Text(error)
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(Color.sparkError)
                }
                content
            }
            .padding(.horizontal, SparkSpacing.lg)
            .padding(.top, SparkSpacing.md)
            .padding(.bottom, SparkSpacing.xl)
        }
        .background(Color.sparkSurface.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await reload() }
        .task(id: trimmedQuery) {
            if viewModel == nil {
                viewModel = TagTypeViewModel(type: type, apiClient: appModel.apiClient)
            }
            if !trimmedQuery.isEmpty {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
            }
            await reload()
        }
    }

    private func reload() async {
        await viewModel?.load(query: trimmedQuery.isEmpty ? nil : trimmedQuery)
    }

    @ViewBuilder
    private var content: some View {
        let tags = viewModel?.tags ?? []
        if tags.isEmpty {
            if viewModel?.isLoading == true || viewModel?.hasLoaded != true {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SparkSpacing.xxxl)
            } else if trimmedQuery.isEmpty {
                EmptyState(
                    systemImage: "tag",
                    title: "No \(title.lowercased()) yet",
                    message: "Tags of this type show up here once something carries one."
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, SparkSpacing.xxxl)
            } else {
                EmptyState(
                    systemImage: "magnifyingglass",
                    title: "No tags match",
                    message: "Try another word, or part of one."
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, SparkSpacing.xxxl)
            }
        } else {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                SparkSectionCaption(text: caption)
                    .padding(.horizontal, SparkSpacing.xs)
                TagRowList(tags: tags, showsType: false) {
                    Task {
                        await viewModel?.load(
                            query: trimmedQuery.isEmpty ? nil : trimmedQuery,
                            reset: false
                        )
                    }
                }
            }
        }
    }

    private var caption: String {
        let name = title.lowercased()
        if !trimmedQuery.isEmpty {
            return "\(title) matching \u{201C}\(trimmedQuery)\u{201D}"
        }
        if let count = viewModel?.tagsCount {
            return "\(count.formatted()) \(name), most used first"
        }
        return "Most used first"
    }
}
