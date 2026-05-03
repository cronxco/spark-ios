import SparkKit
import SparkUI
import SwiftData
import SwiftUI

struct NotificationsInboxView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: NotificationsInboxViewModel?
    @State private var path: [DetailRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("Inbox")
                .navigationBarTitleDisplayMode(.large)
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
                .toolbar {
                    if let viewModel, !viewModel.items.isEmpty {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Mark all read") {
                                Task { await viewModel.markAllRead() }
                            }
                            .font(SparkTypography.bodySmall)
                        }
                    }
                }
        }
        .task {
            if viewModel == nil {
                viewModel = NotificationsInboxViewModel(
                    apiClient: appModel.apiClient,
                    container: appModel.container
                )
            }
            await viewModel?.refresh()
        }
        .refreshable {
            await viewModel?.refresh()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let viewModel {
            switch viewModel.state {
            case .loaded:
                if viewModel.items.isEmpty {
                    EmptyState(
                        systemImage: "bell.slash",
                        title: "All caught up",
                        message: "Anomalies, digests, and integration alerts will land here."
                    )
                } else {
                    List {
                        ForEach(viewModel.items) { item in
                            NotificationRow(item: item)
                                .contentShape(Rectangle())
                                .onTapGesture { handleTap(item) }
                                .onAppear {
                                    if !item.isRead {
                                        Task { await viewModel.markRead(item.id) }
                                    }
                                    if item.id == viewModel.items.last?.id, viewModel.hasMore {
                                        Task { await viewModel.loadMore() }
                                    }
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task { await viewModel.delete(item.id) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                        if viewModel.isLoadingMore {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                }
            case .error(let msg):
                EmptyState(
                    systemImage: "exclamationmark.triangle.fill",
                    title: "Couldn't load",
                    message: msg,
                    actionTitle: "Retry"
                ) { Task { await viewModel.refresh() } }
            case .loading, .idle:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func handleTap(_ item: NotificationItem) {
        guard let entity = item.entity else { return }
        let route: DetailRoute? = switch entity.kind {
        case .event: .event(id: entity.id)
        case .object: .object(id: entity.id)
        case .metric: .metric(identifier: entity.id)
        case .place: .place(id: entity.id)
        case .integration: .integration(service: entity.id)
        case .anomaly: nil  // No dedicated anomaly screen yet — Phase 3.
        }
        if let route, path.last != route {
            path.append(route)
        }
    }
}

private struct NotificationRow: View {
    let item: NotificationItem

    var body: some View {
        HStack(alignment: .top, spacing: SparkSpacing.md) {
            DomainGlyph(icon: glyph, tint: tint, size: 30)
            VStack(alignment: .leading, spacing: SparkSpacing.xxs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.title)
                        .font(item.isRead ? SparkTypography.body : SparkTypography.bodyStrong)
                        .lineLimit(2)
                    Spacer(minLength: SparkSpacing.sm)
                    Text(Self.relative(from: item.receivedAt))
                        .font(SparkTypography.monoSmall)
                        .foregroundStyle(.secondary)
                }
                if let body = item.body {
                    Text(body)
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            if !item.isRead {
                Circle()
                    .fill(Color.sparkAccent)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
            }
        }
        .padding(.vertical, SparkSpacing.xs)
    }

    private var glyph: String {
        switch item.domain?.lowercased() {
        case "health": "heart.fill"
        case "activity": "figure.run"
        case "money": "creditcard.fill"
        case "media": "music.note"
        case "knowledge": "book.fill"
        case "anomaly": "exclamationmark.triangle.fill"
        default: "bell.fill"
        }
    }

    private var tint: Color {
        guard let domain = item.domain else { return .sparkAccent }
        return Color.domainTint(for: domain)
    }

    private static func relative(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}
