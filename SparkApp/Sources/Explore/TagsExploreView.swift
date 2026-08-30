import Observation
import SparkKit
import SparkUI
import SwiftUI

@MainActor
@Observable
private final class TagsExploreViewModel {
    private let apiClient: APIClient
    private(set) var tags: [TagResource] = []
    private(set) var nextCursor: String?
    private(set) var hasMore = false
    private(set) var isLoading = false
    private(set) var error: String?

    init(apiClient: APIClient) { self.apiClient = apiClient }

    func load(query: String? = nil, reset: Bool = true) async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let page = try await apiClient.request(TagsEndpoint.list(query: query, cursor: reset ? nil : nextCursor))
            tags = reset ? page.data : tags + page.data
            nextCursor = page.nextCursor
            hasMore = page.hasMore
        } catch APIError.notModified { } catch {
            SparkObservability.captureHandled(error)
            self.error = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }
}

struct TagsExploreView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: TagsExploreViewModel?
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                if let error = viewModel?.error {
                    Section { Text(error).foregroundStyle(Color.sparkError) }
                }
                ForEach(viewModel?.tags ?? []) { tag in
                    NavigationLink(value: DetailRoute.tag(id: tag.id, name: tag.name, type: tag.type)) {
                        HStack {
                            TagChip(tag.eventTag)
                            Spacer()
                            Text("\(tag.totalCount)")
                                .font(SparkTypography.monoSmall)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if viewModel?.hasMore == true {
                    Button(viewModel?.isLoading == true ? "Loading…" : "Load more") {
                        Task { await viewModel?.load(query: query.nilIfEmpty, reset: false) }
                    }
                    .disabled(viewModel?.isLoading == true)
                }
            }
            .scrollContentBackground(.hidden)
            .sparkAppBackground()
            .navigationTitle("Tags")
            .searchable(text: $query, prompt: "Find tags")
            .onChange(of: query) { _, value in
                Task { await viewModel?.load(query: value.nilIfEmpty) }
            }
            .sparkDetailDestinations()
            .task {
                if viewModel == nil { viewModel = TagsExploreViewModel(apiClient: appModel.apiClient) }
                await viewModel?.load()
            }
        }
    }
}

private extension String { var nilIfEmpty: String? { isEmpty ? nil : self } }
