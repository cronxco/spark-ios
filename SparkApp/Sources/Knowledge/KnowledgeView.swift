import SparkKit
import SparkUI
import SwiftUI

struct KnowledgeView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: KnowledgeViewModel?
    @State private var path: [Event] = []

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("Knowledge")
                .navigationBarTitleDisplayMode(.large)
                .navigationDestination(for: Event.self) { event in
                    KnowledgeItemDetailView(event: event)
                }
        }
        .task {
            if viewModel == nil {
                viewModel = KnowledgeViewModel(apiClient: appModel.apiClient)
            }
            await viewModel?.initialLoad()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let viewModel {
            mainContent(viewModel: viewModel)
        } else {
            loadingPlaceholder
        }
    }

    private func mainContent(viewModel: KnowledgeViewModel) -> some View {
        ScrollView {
            VStack(spacing: SparkSpacing.lg) {
                filterRow(viewModel: viewModel)
                    .padding(.horizontal, SparkSpacing.lg)

                let items = viewModel.filteredItems
                let isEmpty = viewModel.allItems.isEmpty

                switch viewModel.loadState {
                case .idle:
                    shimmerStack.padding(.horizontal, SparkSpacing.lg)
                case .loading where isEmpty:
                    shimmerStack.padding(.horizontal, SparkSpacing.lg)

                case .error(let msg) where isEmpty:
                    EmptyState(
                        systemImage: "exclamationmark.triangle.fill",
                        title: "Couldn't load articles",
                        message: msg,
                        actionTitle: "Retry"
                    ) { Task { await viewModel.refresh() } }
                    .padding(.horizontal, SparkSpacing.lg)

                default:
                    if items.isEmpty {
                        EmptyState(
                            systemImage: "doc.richtext",
                            title: "Nothing here yet",
                            message: "Articles, newsletters and web digests will appear as they're ingested."
                        )
                        .padding(.horizontal, SparkSpacing.lg)
                    } else {
                        LazyVStack(spacing: SparkSpacing.md) {
                            ForEach(items) { event in
                                NavigationLink(value: event) {
                                    KnowledgeItemCard(event: event)
                                }
                                .buttonStyle(.plain)
                                .onAppear {
                                    if event.id == items.last?.id {
                                        Task { await viewModel.loadMore() }
                                    }
                                }
                            }
                            if case .loading = viewModel.loadState {
                                LoadingShimmerCard().frame(height: 220)
                            }
                        }
                        .padding(.horizontal, SparkSpacing.lg)
                    }
                }
            }
            .padding(.vertical, SparkSpacing.xl)
        }
        .refreshable { await viewModel.refresh() }
        .background(Color.sparkSurface.ignoresSafeArea())
    }

    private func filterRow(viewModel: KnowledgeViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SparkSpacing.sm) {
                ForEach(KnowledgeViewModel.Filter.allCases) { f in
                    Button {
                        viewModel.filter = f
                    } label: {
                        TagChip(f.rawValue, isGhost: viewModel.filter != f)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var shimmerStack: some View {
        VStack(spacing: SparkSpacing.md) {
            ForEach(0..<3, id: \.self) { _ in
                LoadingShimmerCard().frame(height: 220)
            }
        }
    }

    private var loadingPlaceholder: some View {
        ScrollView {
            VStack(spacing: SparkSpacing.md) {
                ForEach(0..<3, id: \.self) { _ in
                    LoadingShimmerCard().frame(height: 220)
                }
            }
            .padding(SparkSpacing.lg)
        }
    }
}

// MARK: - Knowledge Item Card

private struct KnowledgeItemCard: View {
    let event: Event

    private var imageUrl: URL? {
        guard let raw = event.target?.mediaUrl else { return nil }
        return URL(string: raw)
    }

    private var title: String {
        event.target?.title ?? event.action.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private var source: String {
        event.actor?.title ?? event.service.capitalized
    }

    private var serviceLabel: String {
        switch event.service {
        case "newsletter": "Newsletter"
        case "fetch": "Web Digest"
        default: event.service.capitalized
        }
    }

    var body: some View {
        GlassCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Group {
                    if let url = imageUrl {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                imagePlaceholder
                            }
                        }
                    } else {
                        imagePlaceholder
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .clipped()

                VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                    HStack(spacing: SparkSpacing.xs) {
                        Text(source)
                            .font(SparkTypography.captionStrong)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        if let time = event.time {
                            Text(time.formatted(.relative(presentation: .named)))
                                .font(SparkTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(title)
                        .font(SparkTypography.bodyStrong)
                        .lineLimit(2)
                        .foregroundStyle(.primary)

                    if let tldr = event.tldr {
                        Text(tldr)
                            .font(SparkTypography.bodySmall)
                            .foregroundStyle(.secondary)
                            .italic()
                            .lineLimit(2)
                    }

                    HStack {
                        Text(serviceLabel)
                            .font(SparkTypography.monoSmall)
                            .foregroundStyle(Color.domainKnowledge)
                            .padding(.horizontal, SparkSpacing.sm)
                            .padding(.vertical, 3)
                            .background(Color.domainKnowledge.opacity(0.12))
                            .clipShape(.capsule)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(SparkSpacing.lg)
            }
        }
    }

    private var imagePlaceholder: some View {
        Color.sparkElevated
            .overlay(
                Image(systemName: "doc.richtext")
                    .font(.title)
                    .foregroundStyle(.tertiary)
            )
    }
}
