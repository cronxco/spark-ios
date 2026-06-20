import SparkKit
import SparkUI
import SwiftUI

struct KnowledgeView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.tabAccessoryCoordinator) private var tabAccessoryCoordinator
    @State private var viewModel: KnowledgeViewModel?
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            content
                .sparkScrollingNavigationBar()
                .sparkMainNavigationTitle("Knowledge")
                .navigationDestination(for: Event.self) { event in
                    KnowledgeItemDetailView(event: event)
                }
                .sparkDetailDestinations()
                .sparkMainAppToolbar()
                .onAppear { updateFilterAccessory() }
                .onChange(of: viewModel?.filter) { _, _ in updateFilterAccessory() }
                .onChange(of: path.count) { _, _ in updateFilterAccessory() }
                .onDisappear { tabAccessoryCoordinator?.clear(owner: .knowledge) }
        }
        .task {
            if viewModel == nil {
                viewModel = KnowledgeViewModel(apiClient: appModel.apiClient)
            }
            await viewModel?.initialLoad()
            updateFilterAccessory()
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
                pageHeader(viewModel: viewModel)
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
            .padding(.top, SparkSpacing.md)
            .padding(.bottom, SparkSpacing.xl)
        }
        .refreshable { await viewModel.refresh() }
        .sparkAppBackground()
    }

    private func updateFilterAccessory() {
        guard path.isEmpty else {
            tabAccessoryCoordinator?.clear(owner: .knowledge)
            return
        }

        registerFilterAccessory()
    }

    private func registerFilterAccessory() {
        guard let viewModel else { return }

        tabAccessoryCoordinator?.set(
            TabAccessory(
                owner: .knowledge,
                title: "Knowledge filter",
                items: KnowledgeViewModel.Filter.allCases.map {
                    TabAccessoryItem(id: $0.id, title: $0.rawValue, systemImage: filterIcon($0))
                },
                selectedID: viewModel.filter.id,
                select: { id in
                    guard let filter = KnowledgeViewModel.Filter(rawValue: id) else { return }
                    viewModel.filter = filter
                }
            )
        )
    }

    private func filterIcon(_ filter: KnowledgeViewModel.Filter) -> String {
        switch filter {
        case .reading: "newspaper.fill"
        case .personal: "person.crop.circle.fill"
        case .all: "square.grid.2x2.fill"
        }
    }

    private func pageHeader(viewModel: KnowledgeViewModel) -> some View {
        SparkMainPageHeader(title: "Knowledge", subtitle: headerSubtitle(viewModel: viewModel))
    }

    private func headerSubtitle(viewModel: KnowledgeViewModel) -> String {
        switch viewModel.loadState {
        case .idle:
            return "Loading your reading"
        case .loading where viewModel.allItems.isEmpty:
            return "Loading your reading"
        case .error where viewModel.allItems.isEmpty:
            return "Knowledge unavailable"
        default:
            let count = viewModel.filteredItems.count
            let noun = count == 1 ? "item" : "items"
            return "\(count) \(noun) in \(viewModel.filter.rawValue)"
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
        .sparkAppBackground()
    }
}

// MARK: - Knowledge Item Card

private struct KnowledgeItemCard: View {
    let event: Event
    @Environment(\.colorScheme) private var colorScheme

    private let cardRadius: CGFloat = 20

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
        case "fetch": "Web Digest"
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

    private var accent: Color {
        let palette: [Color] = [
            .spark400,
            .spark500,
            .ocean300,
            .ember300,
            .sparkSuccess,
            .sparkWarning,
        ]
        return palette[stablePaletteIndex % palette.count]
    }

    private var stablePaletteIndex: Int {
        let seed = event.id + title + event.service
        return seed.unicodeScalars.reduce(0) { partial, scalar in
            (partial &* 31 &+ Int(scalar.value)) & 0x7fffffff
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
                            .foregroundStyle(accent)
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
