import SparkKit
import SparkUI
import SwiftUI

struct SearchView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: SearchViewModel?
    @State private var path: [DetailRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("Search")
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
                    }
                }
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
            modePills
                .padding(.horizontal, SparkSpacing.lg)
                .padding(.bottom, SparkSpacing.sm)
            Divider()
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
                        TagChip(pillLabel(for: mode), isGhost: !isActive)
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
                EmptyState(
                    systemImage: "magnifyingglass",
                    title: "Search Spark",
                    message: "Try `>` for actions, `#` for tags, `$` for metrics, `@` for integrations, `~` for semantic."
                )
            case .searching:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .results(let items) where items.isEmpty:
                EmptyState(
                    systemImage: "questionmark.circle",
                    title: "No matches",
                    message: "Try a different word or mode."
                )
            case .results:
                List {
                    ForEach(viewModel.grouped, id: \.0) { group in
                        Section(group.0) {
                            ForEach(group.1) { result in
                                Button {
                                    handleTap(result)
                                } label: {
                                    SearchResultRow(result: result)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .listStyle(.plain)
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
        .padding(.vertical, SparkSpacing.xs)
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
