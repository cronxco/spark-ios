import SparkKit
import SparkUI
import SwiftUI

struct KnowledgeView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: KnowledgeViewModel?
    @State private var path = NavigationPath()
    @State private var filter: KnowledgeViewModel.Filter = .reading

    var body: some View {
        NavigationStack(path: $path) {
            SparkSectionPager(
                title: "Knowledge",
                sections: KnowledgeViewModel.Filter.allCases.map { SparkPagerSection(id: $0, title: $0.rawValue) },
                selection: $filter
            ) { filter in
                page(filter: filter)
            }
            .sparkMainNavigationTitle("Knowledge")
            .navigationDestination(for: Event.self) { event in
                KnowledgeItemDetailView(event: event)
            }
            .sparkDetailDestinations()
            .sparkMainAppToolbar()
        }
        .onChange(of: filter) { _, filter in
            viewModel?.filter = filter
        }
        .task {
            if viewModel == nil {
                viewModel = KnowledgeViewModel(apiClient: appModel.apiClient)
            }
            await viewModel?.initialLoad()
        }
    }

    @ViewBuilder
    private func page(filter: KnowledgeViewModel.Filter) -> some View {
        if let viewModel {
            mainContent(viewModel: viewModel, filter: filter)
        } else {
            loadingPlaceholder
        }
    }

    private func mainContent(viewModel: KnowledgeViewModel, filter: KnowledgeViewModel.Filter) -> some View {
        ScrollView {
            VStack(spacing: SparkSpacing.lg) {
                SparkSectionCaption(text: headerSubtitle(viewModel: viewModel, filter: filter))
                    .padding(.horizontal, SparkSpacing.lg)

                let items = viewModel.items(for: filter)
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
            .padding(.top, SparkSpacing.md)
            .padding(.bottom, SparkSpacing.xl)
        }
        .refreshable { await viewModel.refresh() }
    }

    private func headerSubtitle(viewModel: KnowledgeViewModel, filter: KnowledgeViewModel.Filter) -> String {
        switch viewModel.loadState {
        case .idle:
            return "Loading your reading"
        case .loading where viewModel.allItems.isEmpty:
            return "Loading your reading"
        case .error where viewModel.allItems.isEmpty:
            return "Knowledge unavailable"
        default:
            let count = viewModel.items(for: filter).count
            let noun = count == 1 ? "item" : "items"
            return "\(count) \(noun) in \(filter.rawValue)"
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
    @Environment(\.colorScheme) private var colorScheme

    private let cardRadius: CGFloat = SparkRadii.lg

    private var imageUrl: URL? {
        guard let raw = event.target?.mediaUrl else { return nil }
        return URL(string: raw)
    }

    private var title: String {
        event.target?.title ?? event.displayName ?? event.action.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private var source: String {
        event.actor?.title ?? event.service.capitalized
    }

    private var serviceLabel: String {
        switch event.service {
        case "newsletter": "Newsletter"
        case "fetch": "Web digest"
        case "outline": "Outline"
        case "calendar": "Calendar"
        default: event.service.capitalized
        }
    }

    private var serviceIcon: String {
        switch event.service {
        case "newsletter": "newspaper.fill"
        case "fetch": "safari.fill"
        case "outline": "list.bullet.rectangle.fill"
        case "calendar": "calendar"
        default: "books.vertical.fill"
        }
    }

    /// Knowledge is the sky domain. Shades of it tell sources apart; other
    /// domain colours would say "money" or "anomaly" about a newsletter.
    private var accent: Color {
        switch event.service {
        case "newsletter": .sky5
        case "fetch": .sky6
        case "outline": .sky7
        case "calendar": .sky4
        default: .domainKnowledge
        }
    }

    var body: some View {
        GlassCard(radius: cardRadius, padding: 0) {
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
                        SparkRichContentText(text: tldr, font: SparkTypography.bodySmall, foregroundStyle: .secondary)
                            .italic()
                            .lineLimit(2)
                    }

                    HStack {
                        Text(serviceLabel)
                            .font(SparkTypography.monoSmall)
                            .foregroundStyle(Color.domainKnowledge)
                            .padding(.horizontal, SparkSpacing.sm)
                            .padding(.vertical, 3)
                            .background(accent.opacity(colorScheme == .dark ? 0.20 : 0.12))
                            .clipShape(.capsule)
                        if let count = event.blocksCount, count > 0 {
                            Text("\(count) blocks")
                                .font(SparkTypography.monoSmall)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(SparkSpacing.lg)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
    }

    private var imagePlaceholder: some View {
        Rectangle()
            .fill(accent.opacity(colorScheme == .dark ? 0.62 : 0.82))
            .overlay(alignment: .center) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 88, weight: .light))
                    .foregroundStyle(.white.opacity(0.26))
                    .offset(x: 58, y: 8)
            }
            .overlay(alignment: .bottomLeading) {
                Image(systemName: serviceIcon)
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(.white.opacity(0.78))
                    .padding(SparkSpacing.lg)
            }
    }
}
