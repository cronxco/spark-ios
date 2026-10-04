import SparkKit
import SparkUI
import SwiftData
import SwiftUI

struct NotificationsInboxView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: NotificationsInboxViewModel?
    @State private var path: [DetailRoute] = []
    @State private var scope: NotificationsEndpoint.Scope = .active
    @State private var stream: NotificationFeedItem.Stream?
    @State private var search = ""
    @State private var selectedDetail: NotificationFeedItem?

    private var filterKey: String {
        "\(scope.rawValue)|\(stream?.rawValue ?? "all")|\(search)"
    }

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("Notifications")
                .navigationBarTitleDisplayMode(.large)
                .navigationDestination(for: DetailRoute.self) { route in
                    destination(for: route)
                }
                .toolbar {
                    if let viewModel, viewModel.hasUnread, scope == .active {
                        ToolbarItem(placement: .primaryAction) {
                            Button("Mark all read") { Task { await viewModel.markAllRead() } }
                                .font(SparkTypography.bodySmall)
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { dismiss() } label: { Image(systemName: "xmark") }
                            .accessibilityLabel("Close notifications")
                    }
                }
        }
        .searchable(text: $search, prompt: "Search notifications")
        .task(id: filterKey) {
            if viewModel == nil {
                viewModel = NotificationsInboxViewModel(apiClient: appModel.apiClient, container: appModel.container)
            }
            if !search.isEmpty {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
            }
            await viewModel?.refresh(scope: scope, stream: stream, search: search)
        }
        .refreshable {
            await viewModel?.refresh(scope: scope, stream: stream, search: search)
        }
        .onReceive(NotificationCenter.default.publisher(for: .sparkNotificationFeedChanged)) { _ in
            Task { await viewModel?.refresh(scope: scope, stream: stream, search: search) }
        }
        .sheet(item: $selectedDetail) { item in
            NotificationDetailSheet(item: item)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let viewModel {
            switch viewModel.state {
            case .loaded:
                feed(viewModel)
            case .error(let message):
                EmptyState(
                    systemImage: "wifi.exclamationmark",
                    title: "Couldn’t load notifications",
                    message: message,
                    actionTitle: "Retry"
                ) { Task { await viewModel.refresh(scope: scope, stream: stream, search: search) } }
            case .loading, .idle:
                ProgressView("Loading notifications…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func feed(_ viewModel: NotificationsInboxViewModel) -> some View {
        List {
            if viewModel.isShowingCachedData {
                Label("Showing saved notifications while Spark reconnects", systemImage: "wifi.slash")
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.sparkWarning.opacity(0.12))
                    .accessibilityLabel("Offline. Showing saved notifications.")
            }

            Section {
                Picker("View", selection: $scope) {
                    Text("Inbox").tag(NotificationsEndpoint.Scope.active)
                    Text("History").tag(NotificationsEndpoint.Scope.history)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Notification history")

                streamPicker(counts: viewModel.counts)
                    .listRowInsets(EdgeInsets(top: SparkSpacing.sm, leading: 0, bottom: SparkSpacing.sm, trailing: 0))
            }
            .listRowBackground(Color.clear)

            if viewModel.items.isEmpty {
                Section {
                    EmptyState(
                        systemImage: scope == .history ? "archivebox" : "checkmark.circle",
                        title: scope == .history ? "No notification history" : "You’re all caught up",
                        message: search.isEmpty
                            ? "Updates, active work, and items needing attention will appear here."
                            : "Try a different search or stream."
                    )
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ForEach(viewModel.items) { item in
                        feedRow(item, viewModel: viewModel)
                    }
                } header: {
                    Text(summary(for: viewModel.counts))
                }
            }

            if viewModel.isLoadingMore {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowSeparator(.hidden)
            } else if viewModel.hasMore {
                Color.clear
                    .frame(height: 1)
                    .onAppear { Task { await viewModel.loadMore() } }
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func feedRow(_ item: NotificationFeedItem, viewModel: NotificationsInboxViewModel) -> some View {
        if item.kind == .notification && scope == .active {
            NotificationFeedRow(item: item)
                .contentShape(Rectangle())
                .onTapGesture { handleTap(item, viewModel: viewModel) }
                .swipeActions(edge: .trailing) {
                    Button {
                        Task { await viewModel.archive(item.id) }
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                    .tint(.sparkWarning)

                    Button {
                        Task {
                            if item.isRead { await viewModel.markUnread(item.id) }
                            else { await viewModel.markRead(item.id) }
                        }
                    } label: {
                        Label(item.isRead ? "Unread" : "Read", systemImage: item.isRead ? "envelope.badge" : "envelope.open")
                    }
                    .tint(.sparkAccent)
                }
        } else {
            NotificationFeedRow(item: item)
                .contentShape(Rectangle())
                .onTapGesture { handleTap(item, viewModel: viewModel) }
        }
    }

    private func streamPicker(counts: NotificationFeedCounts) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: SparkSpacing.sm) {
                streamButton(title: "All", value: nil, count: nil)
                streamButton(title: "Attention", value: .attention, count: counts.unresolvedAttention)
                streamButton(title: "Activity", value: .activity, count: counts.activeActivity)
                streamButton(title: "Updates", value: .updates, count: nil)
                streamButton(title: "System", value: .system, count: nil)
            }
            .padding(.horizontal, SparkSpacing.lg)
        }
        .scrollIndicators(.hidden)
        .accessibilityLabel("Notification streams")
    }

    private func streamButton(title: String, value: NotificationFeedItem.Stream?, count: Int?) -> some View {
        Button {
            stream = value
        } label: {
            HStack(spacing: SparkSpacing.xs) {
                Text(title)
                if let count, count > 0 {
                    Text("\(count)")
                        .font(.caption2.monospacedDigit())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(value == .attention ? Color.sparkError : Color.sparkAccent, in: Capsule())
                        .foregroundStyle(.white)
                }
            }
            .font(SparkTypography.bodySmall)
            .foregroundStyle(stream == value ? Color.white : Color.primary)
            .padding(.horizontal, SparkSpacing.md)
            .frame(minHeight: 36)
            .background(stream == value ? Color.primary : Color.secondary.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(stream == value ? .isSelected : [])
    }

    private func summary(for counts: NotificationFeedCounts) -> String {
        if scope == .history { return "History" }
        if counts.unresolvedAttention > 0 { return "\(counts.unresolvedAttention) need attention" }
        if counts.activeActivity > 0 { return "\(counts.activeActivity) active" }
        if counts.unread > 0 { return "\(counts.unread) unread" }
        return "Recent"
    }

    private func handleTap(_ item: NotificationFeedItem, viewModel: NotificationsInboxViewModel) {
        if item.kind == .notification && !item.isRead {
            Task { await viewModel.markRead(item.id) }
        }

        guard let route = route(for: item) else {
            selectedDetail = item
            return
        }
        if path.last != route { path.append(route) }
    }

    private func route(for item: NotificationFeedItem) -> DetailRoute? {
        if let entity = item.entity {
            return switch entity.kind {
            case .event: .event(id: entity.id)
            case .object: .object(id: entity.id)
            case .metric: .metric(identifier: entity.id)
            case .place: .place(id: entity.id)
            case .integration: .integration(service: entity.id)
            case .anomaly: .anomaly(id: entity.id)
            }
        }

        guard let destination = item.destination, let appRoute = AppModel.route(from: destination) else { return nil }
        return switch appRoute {
        case .event(let id): .event(id: id)
        case .object(let id): .object(id: id)
        case .block(let id): .block(id: id)
        case .metric(let identifier): .metric(identifier: identifier)
        case .place(let id): .place(id: id)
        case .anomaly(let id): .anomaly(id: id)
        case .integration(let service): .integration(service: service)
        case .account(let id): .account(id: id)
        default: nil
        }
    }

    @ViewBuilder
    private func destination(for route: DetailRoute) -> some View {
        switch route {
        case .event(let id): EventDetailView(eventId: id)
        case .object(let id): ObjectDetailView(objectId: id)
        case .block(let id): BlockDetailView(blockId: id)
        case .metric(let identifier): MetricDetailView(identifier: identifier)
        case .place(let id): PlaceDetailView(placeId: id)
        case .anomaly(let id): AnomalyDetailView(anomalyId: id)
        case .integration(let service): IntegrationDetailView(integrationId: service)
        case .account(let id): AccountDetailView(accountId: id)
        case .tag(let id, let name, let type): TagDetailView(tagID: id, tagName: name, tagType: type)
        }
    }
}

private struct NotificationFeedRow: View {
    let item: NotificationFeedItem

    var body: some View {
        HStack(alignment: .top, spacing: SparkSpacing.md) {
            DomainGlyph(icon: icon, tint: tint, size: 32)
            VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.title)
                        .font(item.isRead || item.kind == .activity ? SparkTypography.body : SparkTypography.bodyStrong)
                        .lineLimit(2)
                    Spacer(minLength: SparkSpacing.sm)
                    Text(relativeDate)
                        .font(SparkTypography.monoSmall)
                        .foregroundStyle(.secondary)
                }
                if let body = item.body {
                    Text(body)
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                if let progress = item.progress {
                    ProgressView(value: Double(progress.current), total: Double(max(1, progress.total)))
                        .tint(tint)
                        .accessibilityLabel("\(progress.step), \(percentComplete) percent complete")
                }
                HStack(spacing: SparkSpacing.sm) {
                    Text(item.stream.rawValue.capitalized)
                        .font(SparkTypography.caption)
                        .foregroundStyle(tint)
                    if item.occurrenceCount > 1 {
                        Text("\(item.occurrenceCount) times")
                            .font(SparkTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if !item.isRead && item.kind == .notification {
                Circle().fill(Color.sparkAccent).frame(width: 8, height: 8).padding(.top, 6)
                    .accessibilityLabel("Unread")
            }
        }
        .padding(.vertical, SparkSpacing.xs)
        .accessibilityElement(children: .combine)
    }

    private var icon: String {
        if item.kind == .activity && item.state == .active { return "arrow.trianglehead.2.clockwise.rotate.90" }
        return switch item.severity {
        case .critical, .error: "exclamationmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .success: "checkmark.circle.fill"
        case .info: item.stream == .updates ? "sparkles" : "bell.fill"
        }
    }

    private var tint: Color {
        switch item.severity {
        case .critical, .error: .sparkError
        case .warning: .sparkWarning
        case .success: .sparkSuccess
        case .info: .sparkAccent
        }
    }

    private var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: item.updatedAt ?? item.occurredAt, relativeTo: .now)
    }

    private var percentComplete: Int {
        guard let progress = item.progress else { return 0 }
        return min(100, Int((Double(progress.current) / Double(max(1, progress.total))) * 100))
    }
}

private struct NotificationDetailSheet: View {
    let item: NotificationFeedItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label(item.stream.rawValue.capitalized, systemImage: "bell")
                    if let body = item.body { Text(body).font(SparkTypography.body) }
                    if item.occurrenceCount > 1 { LabeledContent("Occurrences", value: "\(item.occurrenceCount)") }
                    LabeledContent("Updated", value: (item.updatedAt ?? item.occurredAt).formatted(date: .abbreviated, time: .shortened))
                }
                if item.hasTechnicalDetail {
                    Section("Technical details") {
                        Text("Technical diagnostics are kept separate from the human-readable notification and are available from Spark on the web.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(item.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
