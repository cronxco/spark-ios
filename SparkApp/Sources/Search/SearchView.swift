import SparkKit
import SparkUI
import SwiftUI

private let recentSearchesKey = "spark.search.recents"
private let maxRecents = 8

struct SearchView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: SearchViewModel?
    @State private var path: [DetailRoute] = []
    @State private var recentSearches: [String] = {
        UserDefaults.standard.stringArray(forKey: recentSearchesKey) ?? []
    }()

    var body: some View {
        NavigationStack(path: $path) {
            content
                .sparkAppBackground()
                .navigationTitle("Search")
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: DetailRoute.self) { route in
                    switch route {
                    case .event(let id):
                        EventDetailView(eventId: id)
                    case .object(let id):
                        ObjectDetailView(objectId: id)
                    case .block(let id):
                        BlockDetailView(blockId: id)
                    case .metric(let identifier):
                        MetricDetailView(identifier: identifier)
                    case .place(let id):
                        PlaceDetailView(placeId: id)
                    case .integration(let service):
                        IntegrationDetailView(integrationId: service)
                    case .account(let id):
                        AccountDetailView(accountId: id)
                    }
                }
                .sparkMainNavigationTitle("Search")
                .sparkMainAppToolbar()
        }
        .searchable(
            text: queryBinding,
            placement: .automatic,
            prompt: "Search events, objects, metrics…"
        )
        .searchToolbarBehavior(.minimize)
        .task {
            if viewModel == nil {
                viewModel = SearchViewModel(apiClient: appModel.apiClient)
            }
        }
    }

    private var queryBinding: Binding<String> {
        Binding(
            get: { viewModel?.query ?? "" },
            set: { viewModel?.query = $0 }
        )
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            SparkMainPageHeader(
                title: "Search",
                subtitle: "Find events, entities, metrics, integrations, and tags"
            )
            .padding(.horizontal, SparkSpacing.lg)
            .padding(.top, SparkSpacing.md)
            .padding(.bottom, SparkSpacing.md)

            modePills
                .padding(.horizontal, SparkSpacing.lg)
                .padding(.bottom, SparkSpacing.sm)
            results
        }
    }

    private var modePills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SparkSpacing.sm) {
                ForEach(SearchEndpoint.Mode.allCases, id: \.self) { mode in
                    let isActive = viewModel?.mode == mode
                    Button {
                        viewModel?.setMode(mode)
                    } label: {
                        SearchFilterChip(pillLabel(for: mode), isSelected: isActive)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func pillLabel(for mode: SearchEndpoint.Mode) -> String {
        if let symbol = mode.symbol {
            return "\(symbol)  \(mode.label)"
        }
        return mode.label
    }

    @ViewBuilder
    private var results: some View {
        if let viewModel {
            switch viewModel.state {
            case .idle:
                idleState(viewModel: viewModel)
            case .searching:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .results(let items) where items.isEmpty:
                EmptyState(
                    systemImage: "magnifyingglass",
                    title: "No results for \u{201C}\(viewModel.query)\u{201D}",
                    message: "Try a shorter search or switch mode."
                )
            case .results:
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: SparkSpacing.lg) {
                        ForEach(viewModel.grouped, id: \.0) { group in
                            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                                Text(group.0)
                                    .font(SparkTypography.monoSmall)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                    .padding(.horizontal, SparkSpacing.xs)

                                VStack(spacing: SparkSpacing.sm) {
                                    ForEach(group.1) { result in
                                        Button {
                                            saveRecent(viewModel.query)
                                            handleTap(result)
                                        } label: {
                                            SearchResultRow(result: result)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, SparkSpacing.lg)
                    .padding(.top, SparkSpacing.lg)
                    .padding(.bottom, SparkSpacing.xxxl)
                }
            case .error(let msg):
                EmptyState(
                    systemImage: "exclamationmark.triangle.fill",
                    title: "Couldn't search",
                    message: msg
                )
            }
        } else {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func idleState(viewModel: SearchViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SparkSpacing.xl) {
                // Suggestion chips
                GlassCard {
                    VStack(alignment: .leading, spacing: SparkSpacing.md) {
                        Text("Suggestions")
                            .font(SparkTypography.captionStrong)
                            .foregroundStyle(.secondary)
                        HStack(spacing: SparkSpacing.sm) {
                            ForEach(suggestions, id: \.label) { suggestion in
                                Button {
                                    viewModel.setMode(suggestion.mode)
                                    viewModel.query = suggestion.prefix
                                } label: {
                                    HStack(spacing: SparkSpacing.xs) {
                                        Image(systemName: suggestion.icon)
                                        Text(suggestion.label)
                                    }
                                    .font(SparkTypography.captionStrong)
                                    .padding(.horizontal, SparkSpacing.md)
                                    .padding(.vertical, SparkSpacing.sm)
                                    .sparkGlass(.capsule, tint: Color.sparkAccent.opacity(0.1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Text("Try `>` actions · `#` tags · `$` metrics · `@` integrations · `~` semantic")
                            .font(SparkTypography.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                // Recent searches
                if !recentSearches.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                            HStack {
                                Text("Recent")
                                    .font(SparkTypography.captionStrong)
                                    .foregroundStyle(.secondary)
                                Spacer(minLength: 0)
                                Button("Clear") { clearRecents() }
                                    .font(SparkTypography.caption)
                                    .foregroundStyle(Color.sparkAccent)
                            }
                            ForEach(recentSearches, id: \.self) { query in
                                Button {
                                    viewModel.query = query
                                } label: {
                                    HStack(spacing: SparkSpacing.md) {
                                        Image(systemName: "clock")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(query)
                                            .font(SparkTypography.body)
                                            .foregroundStyle(.primary)
                                        Spacer(minLength: 0)
                                        Image(systemName: "arrow.up.left")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.vertical, SparkSpacing.xs)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, SparkSpacing.lg)
            .padding(.vertical, SparkSpacing.lg)
        }
    }

    private var suggestions: [(label: String, icon: String, mode: SearchEndpoint.Mode, prefix: String)] {
        [
            ("People", "person.2", .default, ""),
            ("Places", "mappin", .default, ""),
            ("Metrics", "chart.line.uptrend.xyaxis", .metrics, "$"),
            ("Tags", "tag", .tags, "#"),
        ]
    }

    private func saveRecent(_ query: String) {
        let clean = query.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty else { return }
        var updated = recentSearches.filter { $0 != clean }
        updated.insert(clean, at: 0)
        if updated.count > maxRecents { updated = Array(updated.prefix(maxRecents)) }
        recentSearches = updated
        UserDefaults.standard.set(updated, forKey: recentSearchesKey)
    }

    private func clearRecents() {
        recentSearches = []
        UserDefaults.standard.removeObject(forKey: recentSearchesKey)
    }

    private func handleTap(_ result: SearchResult) {
        let route: DetailRoute? = switch result {
        case .event(let h): .event(id: h.id)
        case .object(let h): .object(id: h.id)
        case .block(let h): .block(id: h.id)
        case .metric(let h): .metric(identifier: h.identifier)
        case .integration(let h): .integration(service: h.id)
        case .place(let h): .place(id: h.id)
        case .intent: nil  // Actions ride the App Intents pipeline (Phase 3).
        }
        if let route, path.last != route {
            path.append(route)
        }
    }
}

private struct SearchResultRow: View {
    let result: SearchResult

    var body: some View {
        HStack(spacing: SparkSpacing.md) {
            DomainGlyph(icon: glyph, tint: tint, size: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(SparkTypography.body)
                    .lineLimit(1)
                if let sub = result.subtitle {
                    Text(sub)
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(SparkSpacing.md)
        .sparkGlass(.roundedRect(SparkRadii.lg), tint: Color.sparkElevated.opacity(0.18))
        .contentShape(Rectangle())
    }

    private var glyph: String {
        switch result {
        case .event: "circle.dotted"
        case .object: "shippingbox"
        case .block: "square.stack.3d.up"
        case .metric: "chart.line.uptrend.xyaxis"
        case .integration: "link"
        case .place: "mappin.circle.fill"
        case .intent(let h): h.symbol ?? "sparkles"
        }
    }

    private var tint: Color {
        switch result {
        case .event(let h): h.domain.map(Color.domainTint(for:)) ?? .sparkAccent
        case .object: .sparkAccent
        case .block: .domainKnowledge
        case .metric(let h): h.domain.map(Color.domainTint(for:)) ?? .sparkAccent
        case .integration: .sparkOcean
        case .place: .sparkAccent
        case .intent: .sparkAccent
        }
    }
}

private struct SearchFilterChip: View {
    let label: String
    let isSelected: Bool

    init(_ label: String, isSelected: Bool) {
        self.label = label
        self.isSelected = isSelected
    }

    var body: some View {
        Text(label)
            .font(SparkTypography.captionStrong)
            .lineLimit(1)
            .padding(.horizontal, SparkSpacing.md)
            .padding(.vertical, SparkSpacing.sm)
            .foregroundStyle(isSelected ? Color.sparkTextPrimary : Color.secondary)
            .background {
                if isSelected {
                    Capsule().fill(Color.sparkAccent)
                } else {
                    Capsule().fill(Color.sparkElevated.opacity(0.16))
                }
            }
            .overlay {
                Capsule()
                    .strokeBorder(
                        isSelected ? Color.clear : Color.primary.opacity(0.12),
                        lineWidth: 1
                    )
            }
            .sparkGlass(.capsule, tint: isSelected ? Color.sparkAccent.opacity(0.18) : Color.clear)
    }
}
