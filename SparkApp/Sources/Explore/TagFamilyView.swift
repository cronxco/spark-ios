import Observation
import SparkKit
import SparkUI
import SwiftUI

@MainActor
@Observable
final class TagFamilyViewModel {
    let family: TagFamily
    private let apiClient: APIClient

    /// The family's types, most used first, with their sizes.
    private(set) var types: [TagTypeTotal] = []
    private(set) var tags: [TagResource] = []
    private(set) var nextCursor: String?
    private(set) var hasMore = false
    private(set) var isLoading = false
    private(set) var hasLoadedTypes = false
    private(set) var error: String?
    private var requestGeneration = 0

    init(family: TagFamily, apiClient: APIClient) {
        self.family = family
        self.apiClient = apiClient
    }

    /// Finds which of the family's types exist, from the first page's totals
    /// (or, from an older server, from the tags on that page).
    func loadTypes() async {
        do {
            let page = try await apiClient.request(TagsEndpoint.list(limit: 100))
            guard !Task.isCancelled else { return }
            let sections = TagCatalogue.sections(tags: page.data, totals: page.types, perGroup: 0)
            let groups = sections.first { $0.family == family }?.groups ?? []
            types = groups.map { TagTypeTotal(type: $0.type, tagsCount: $0.tagsCount, totalCount: $0.totalCount) }
            hasLoadedTypes = true
            error = nil
        } catch APIError.notModified {
            hasLoadedTypes = true
        } catch {
            guard !Task.isCancelled else { return }
            SparkObservability.captureHandled(error)
            self.error = TagsExploreViewModel.message(for: error)
        }
    }

    /// One type's tags, most used first. `reset: false` loads the next page.
    func load(type: String, query: String?, reset: Bool = true) async {
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
            error = nil
        } catch APIError.notModified {
        } catch {
            guard generation == requestGeneration, !Task.isCancelled else { return }
            SparkObservability.captureHandled(error)
            self.error = TagsExploreViewModel.message(for: error)
        }
    }
}

/// See all for one tag family: a type at a time, as rows with their uses,
/// most used first. Pushed from Explore's Tags section.
struct TagFamilyView: View {
    let family: TagFamily

    @Environment(AppModel.self) private var appModel
    @State private var viewModel: TagFamilyViewModel?
    @State private var selectedType: String?
    @State private var query = ""

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var types: [TagTypeTotal] { viewModel?.types ?? [] }
    private var selected: TagTypeTotal? { types.first { $0.type == selectedType } ?? types.first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                if types.count > 1 {
                    typePicker
                }
                if let selected {
                    TagSearchField(
                        prompt: "Find \(TagTypeName.plural(selected.type).lowercased())",
                        text: $query
                    )
                }
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
        .navigationTitle(family.title)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await reload() }
        .task {
            if viewModel == nil {
                viewModel = TagFamilyViewModel(family: family, apiClient: appModel.apiClient)
            }
            if viewModel?.hasLoadedTypes == false {
                await viewModel?.loadTypes()
            }
        }
        .task(id: "\(selected?.type ?? "")|\(trimmedQuery)") {
            guard selected != nil else { return }
            if !trimmedQuery.isEmpty {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
            }
            await reload()
        }
    }

    private func reload() async {
        guard let type = selected?.type else { return }
        await viewModel?.load(type: type, query: trimmedQuery.isEmpty ? nil : trimmedQuery)
    }

    /// Segmented for up to four types; a menu beyond that, where segments
    /// would be too narrow to read.
    @ViewBuilder
    private var typePicker: some View {
        let binding = Binding(
            get: { selected?.type ?? "" },
            set: { selectedType = $0 }
        )
        if types.count <= 4 {
            Picker("Tag type", selection: binding) {
                ForEach(types, id: \.type) { Text(TagTypeName.plural($0.type)).tag($0.type) }
            }
            .pickerStyle(.segmented)
        } else {
            Picker("Tag type", selection: binding) {
                ForEach(types, id: \.type) { Text(TagTypeName.plural($0.type)).tag($0.type) }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
    }

    @ViewBuilder
    private var content: some View {
        let tags = viewModel?.tags ?? []
        if viewModel?.hasLoadedTypes == true, types.isEmpty {
            EmptyState(
                systemImage: "tag",
                title: "No \(family.title.lowercased()) yet",
                message: "Tags of this kind show up here once something carries one."
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, SparkSpacing.xxxl)
        } else if tags.isEmpty {
            if viewModel?.isLoading == true || viewModel?.hasLoadedTypes != true {
                ProgressView()
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
        } else if let selected {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                SparkSectionCaption(text: caption(for: selected))
                    .padding(.horizontal, SparkSpacing.xs)
                TagRowList(tags: tags, showsType: false) {
                    Task {
                        await viewModel?.load(
                            type: selected.type,
                            query: trimmedQuery.isEmpty ? nil : trimmedQuery,
                            reset: false
                        )
                    }
                }
            }
        }
    }

    private func caption(for type: TagTypeTotal) -> String {
        let name = TagTypeName.plural(type.type).lowercased()
        if !trimmedQuery.isEmpty { return "\(name.prefix(1).uppercased() + name.dropFirst()) matching \u{201C}\(trimmedQuery)\u{201D}" }
        return "\(type.tagsCount.formatted()) \(name), most used first"
    }
}
