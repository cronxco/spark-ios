import SparkKit
import SparkUI
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Explore › Metrics: every metric Spark tracks, across services. A list to
/// find a metric and see where it sits against its trend; the trend itself
/// lives on the metric screen (`docs/design-language.md` 7.2, 8).
struct MetricsExploreView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: MetricsExploreViewModel?
    @State private var domainFilter: String?
    @State private var arrangement: MetricArrangement = .byService
    @State private var searchText = ""
    @Binding var path: [DetailRoute]

    private var items: [MetricItem] {
        (viewModel?.metrics ?? []).map { MetricItem(metric: $0, detail: viewModel?.snapshots[$0.identifier]) }
    }

    private var visibleItems: [MetricItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return items.filter { item in
            (domainFilter == nil || item.domain == domainFilter)
                && (query.isEmpty || item.matches(query))
        }
    }

    private var flaggedItems: [MetricItem] {
        visibleItems.filter(\.isFlagged).sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private var groups: [MetricGroup] {
        arrangement.groups(visibleItems)
    }

    private var availableDomains: [DomainChip.Domain] {
        let present = Set(items.map(\.domain))
        return DomainChip.Domain.allCases.filter { present.contains($0.rawValue) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SparkSectionCaption(text: caption)
                    .padding(.horizontal, SparkSpacing.lg)

                controls
                    .padding(.top, SparkSpacing.md)
                    .padding(.horizontal, SparkSpacing.lg)

                if !availableDomains.isEmpty {
                    domainChips
                        .padding(.top, SparkSpacing.md)
                }

                content
                    .padding(.top, SparkSpacing.xl)
            }
            .padding(.top, SparkSpacing.md)
            .padding(.bottom, SparkSpacing.xxl)
        }
        .refreshable { await viewModel?.refresh() }
        .task {
            if viewModel == nil {
                viewModel = MetricsExploreViewModel(apiClient: appModel.apiClient)
            }
            await viewModel?.load()
        }
    }

    // MARK: - Header and controls

    private var caption: String {
        switch viewModel?.metadataState {
        case .loaded(let summary):
            let metrics = summary.activeSourceCount == 1 ? "1 metric" : "\(summary.activeSourceCount) metrics"
            let services = summary.serviceCount == 1 ? "1 service" : "\(summary.serviceCount) services"
            guard let lastSyncAt = summary.lastSyncAt else { return "\(metrics) from \(services)" }
            return "\(metrics) from \(services), synced \(SparkRelativeTime.string(for: lastSyncAt))"
        case .unavailable:
            return "Metrics unavailable"
        case .idle, .none:
            return "Loading metrics"
        }
    }

    private var controls: some View {
        HStack(spacing: SparkSpacing.sm) {
            HStack(spacing: SparkSpacing.sm) {
                SparkGlyph(.search, size: 14, relativeTo: .subheadline)
                    .foregroundStyle(.secondary)
                TextField("Search metrics or services", text: $searchText)
                    .font(SparkTypography.bodySmall)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .sparkGlass(.capsule)

            Menu {
                Picker("Arrange", selection: $arrangement) {
                    ForEach(MetricArrangement.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
            } label: {
                HStack(spacing: SparkSpacing.xs) {
                    SparkGlyph(.filter, size: 13, relativeTo: .caption)
                    Text(arrangement.title)
                        .font(SparkTypography.captionStrong)
                        .lineLimit(1)
                }
                .foregroundStyle(Color.sparkTextPrimary)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .sparkGlass(.capsule)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Arrange metrics, \(arrangement.title)")
        }
    }

    private var domainChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SparkSpacing.sm) {
                Button {
                    domainFilter = nil
                } label: {
                    Text("All")
                        .font(SparkTypography.captionStrong)
                        .foregroundStyle(domainFilter == nil ? Color.sparkOnAccent : Color.sparkTextPrimary)
                        .padding(.horizontal, SparkSpacing.md)
                        .padding(.vertical, SparkSpacing.sm)
                        .background(
                            Capsule().fill(domainFilter == nil ? Color.sparkAccent : Color.primary.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(domainFilter == nil ? .isSelected : [])

                ForEach(availableDomains, id: \.self) { domain in
                    Button {
                        domainFilter = domainFilter == domain.rawValue ? nil : domain.rawValue
                    } label: {
                        DomainChip(domain: domain, isSelected: domainFilter == domain.rawValue)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(domainFilter == domain.rawValue ? .isSelected : [])
                }
            }
            .padding(.horizontal, SparkSpacing.lg)
        }
        .scrollClipDisabled()
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch viewModel?.loadState {
        case .idle, .loading, .none:
            loadingContent
        case .error(let message):
            EmptyState(
                systemImage: "exclamationmark.triangle.fill",
                title: "Couldn't load metrics",
                message: message,
                actionTitle: "Retry"
            ) { Task { await viewModel?.refresh() } }
            .padding(.horizontal, SparkSpacing.lg)
        case .loaded:
            if items.isEmpty {
                EmptyState(
                    systemImage: "chart.line.uptrend.xyaxis",
                    title: "No metrics yet",
                    message: "Metrics appear here once a connected integration sends Spark a reading."
                )
                .padding(.horizontal, SparkSpacing.lg)
            } else if visibleItems.isEmpty {
                EmptyState(
                    systemImage: "magnifyingglass",
                    title: "No matching metrics",
                    message: "Try adjusting your filters."
                )
                .padding(.horizontal, SparkSpacing.lg)
            } else {
                VStack(alignment: .leading, spacing: SparkSpacing.xxl) {
                    if !flaggedItems.isEmpty {
                        flaggedSection
                    }
                    ForEach(groups) { group in
                        groupSection(group)
                    }
                }
                .padding(.horizontal, SparkSpacing.lg)
            }
        }
    }

    private var loadingContent: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            LoadingShimmerCard().frame(height: 120)
            LoadingShimmerCard().frame(height: 260)
        }
        .padding(.horizontal, SparkSpacing.lg)
    }

    private var flaggedSection: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            SectionTitle(title: "Outside usual range", count: flaggedItems.count, icon: .anomaly, tint: .domainAnomaly)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 160), spacing: SparkSpacing.md)],
                alignment: .leading,
                spacing: SparkSpacing.md
            ) {
                ForEach(flaggedItems) { item in
                    Button { open(item) } label: { FlaggedMetricCard(item: item) }
                        .buttonStyle(.plain)
                        .contextMenu { menu(for: item) }
                }
            }
        }
    }

    private func groupSection(_ group: MetricGroup) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            SectionTitle(title: group.title, count: group.items.count)
            LazyVStack(spacing: 0) {
                ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Divider().padding(.leading, 30 + SparkSpacing.md)
                    }
                    Button { open(item) } label: { MetricListRow(item: item) }
                        .buttonStyle(.plain)
                        .contextMenu { menu(for: item) }
                }
            }
            .padding(.horizontal, SparkSpacing.lg)
            .sparkContentSurface(radius: SparkRadii.lg)
        }
    }

    @ViewBuilder
    private func menu(for item: MetricItem) -> some View {
        Button { open(item) } label: { Label("Open metric", systemImage: "chart.xyaxis.line") }
        Button {
            #if canImport(UIKit)
            UIPasteboard.general.string = item.identifier
            #endif
        } label: {
            Label("Copy identifier", systemImage: "doc.on.doc")
        }
    }

    private func open(_ item: MetricItem) {
        path.append(.metric(identifier: item.identifier))
    }
}

// MARK: - Arrangement

/// The sort-and-group menu. By service is the default: a metric is named by
/// the integration that records it, and the domain chips already slice by
/// part of life.
private enum MetricArrangement: CaseIterable, Hashable {
    case byService, needsAttention, recent, name

    var title: String {
        switch self {
        case .byService: "By service"
        case .needsAttention: "Furthest from trend"
        case .recent: "Recently updated"
        case .name: "A to Z"
        }
    }

    func groups(_ items: [MetricItem]) -> [MetricGroup] {
        let byName: (MetricItem, MetricItem) -> Bool = {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
        switch self {
        case .byService:
            let grouped = Dictionary(grouping: items, by: \.serviceName)
            return grouped
                .map { MetricGroup(title: $0.key, items: $0.value.sorted(by: byName)) }
                .sorted { lhs, rhs in
                    // Most recently active service first, so the ones still
                    // sending readings lead.
                    let left = lhs.items.compactMap(\.lastEventAt).max() ?? .distantPast
                    let right = rhs.items.compactMap(\.lastEventAt).max() ?? .distantPast
                    if left != right { return left > right }
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
        case .needsAttention:
            let sorted = items.sorted { lhs, rhs in
                if lhs.isFlagged != rhs.isFlagged { return lhs.isFlagged }
                let left = lhs.deviation ?? -1
                let right = rhs.deviation ?? -1
                if left != right { return left > right }
                return byName(lhs, rhs)
            }
            return [MetricGroup(title: "All metrics", items: sorted)]
        case .recent:
            let sorted = items.sorted { lhs, rhs in
                let left = lhs.lastEventAt ?? .distantPast
                let right = rhs.lastEventAt ?? .distantPast
                if left != right { return left > right }
                return byName(lhs, rhs)
            }
            return [MetricGroup(title: "All metrics", items: sorted)]
        case .name:
            return [MetricGroup(title: "All metrics", items: items.sorted(by: byName))]
        }
    }
}

private struct MetricGroup: Identifiable {
    let title: String
    let items: [MetricItem]
    var id: String { title }
}

// MARK: - Item

/// One metric as the list draws it: names, glyph and the latest reading
/// against its 30-day mean, worked out once.
struct MetricItem: Identifiable {
    let metric: Metric
    let detail: MetricDetail?
    let now: Date

    init(metric: Metric, detail: MetricDetail?, now: Date = .now) {
        self.metric = metric
        self.detail = detail
        self.now = now
    }

    var id: String { metric.identifier }
    var identifier: String { metric.identifier }
    var lastEventAt: Date? { metric.lastEventAt }

    var domain: String {
        guard let domain = metric.domain?.trimmingCharacters(in: .whitespacesAndNewlines), !domain.isEmpty else {
            return metric.service
        }
        return domain.lowercased()
    }

    var title: String { MetricDisplay.title(metric.displayName, service: metric.service) }
    var serviceName: String { MetricDisplay.serviceName(metric.service) }
    var icon: SparkIcon { MetricDisplay.icon(action: metric.action, unit: unit, domain: domain) }
    var tint: Color { EntityPresentation.tint(domain: domain) }
    var unit: String? { detail?.unit ?? metric.unit }

    var latest: MetricDetail.Point? { detail?.series.last }

    var value: MetricDisplay.Value? {
        latest.map { MetricDisplay.format($0.value, unit: unit, action: metric.action) }
    }

    var isScore: Bool { MetricDisplay.isScore(action: metric.action, unit: unit) }

    var daysAgo: Int? { latest.map { MetricDisplay.daysAgo($0.date, now: now) } }

    var comparison: MetricComparison? {
        guard let latest else { return nil }
        return MetricDisplay.comparison(
            value: latest.value,
            mean: detail?.average30d,
            unit: unit,
            action: metric.action
        )
    }

    /// The comparison with "from yesterday" run on when the latest reading
    /// isn't today's.
    var context: String? {
        let stale = daysAgo.flatMap(MetricDisplay.staleness(daysAgo:))
        switch (comparison?.text, stale) {
        case let (text?, stale?): return "\(text), \(stale)"
        case let (text?, nil): return text
        case let (nil, stale?): return stale.prefix(1).uppercased() + stale.dropFirst()
        case (nil, nil): return nil
        }
    }

    /// The latest reading sits outside the usual range.
    var isFlagged: Bool {
        guard let detail, let latest else { return false }
        return detail.anomalies.contains { $0.date == latest.date }
    }

    /// How far the latest reading sits from its mean, as a share of the mean,
    /// for "Furthest from trend".
    var deviation: Double? {
        guard let latest, let mean = detail?.average30d, mean != 0 else { return nil }
        return abs(latest.value - mean) / abs(mean)
    }

    /// "Usual 34.6–36.0°C", for a reading outside it.
    var usualRange: String? {
        guard let baseline = detail?.baseline, baseline.low <= baseline.high else { return nil }
        let low = MetricDisplay.format(max(0, baseline.low), unit: unit, action: metric.action)
        let high = MetricDisplay.format(baseline.high, unit: unit, action: metric.action)
        return "usual \(low.text)–\(high.text)\(high.unit ?? "")"
    }

    func matches(_ query: String) -> Bool {
        [title, serviceName, metric.displayName, metric.identifier, domain]
            .contains { $0.localizedCaseInsensitiveContains(query) }
    }

    var accessibilityLabel: String {
        var parts = [title, serviceName]
        if let value { parts.append([value.text, value.unit].compactMap { $0 }.joined(separator: " ")) }
        if let context { parts.append(context) }
        if isFlagged { parts.append("Outside usual range") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Views

private struct SectionTitle: View {
    let title: String
    let count: Int
    var icon: SparkIcon?
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: SparkSpacing.sm) {
            if let icon {
                SparkGlyph(icon, size: 15, relativeTo: .headline)
                    .foregroundStyle(tint)
            }
            HStack(spacing: SparkSpacing.xs) {
                Text(title)
                    .font(SparkTypography.bodyStrong)
                    .foregroundStyle(Color.sparkTextPrimary)
                Text("(\(count))")
                    .font(SparkTypography.body)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// A `row` (7.2): glyph chip, name over its comparison line, value trailing.
private struct MetricListRow: View {
    let item: MetricItem

    var body: some View {
        HStack(spacing: SparkSpacing.md) {
            DomainGlyph(item.icon, tint: item.tint, size: 30)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: SparkSpacing.xs) {
                    Text(item.title)
                        .font(SparkTypography.bodyStrong)
                        .foregroundStyle(Color.sparkTextPrimary)
                        .lineLimit(1)
                    if item.isFlagged {
                        SparkGlyph(.anomaly, size: 11, relativeTo: .caption)
                            .foregroundStyle(Color.domainAnomaly)
                    }
                }
                if let context = item.context {
                    ComparisonText(comparison: item.comparison, text: context)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let value = item.value {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value.text)
                        .font(SparkTypography.bodyStrong)
                        .foregroundStyle(Color.sparkTextPrimary)
                    if let unit = value.unit {
                        Text(unit)
                            .font(SparkTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .monospacedDigit()
                .lineLimit(1)
                .layoutPriority(1)
            } else if item.detail == nil {
                Text("\u{2014}")
                    .font(SparkTypography.bodyStrong)
                    .foregroundStyle(.secondary)
            }

            SparkGlyph(.forward, size: 12, relativeTo: .caption)
                .foregroundStyle(.tertiary)
        }
        .frame(minHeight: 64)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }
}

/// A `compact` card (7.2) for a reading outside its usual range: eyebrow,
/// hero value or ring, one context line.
private struct FlaggedMetricCard: View {
    let item: MetricItem

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            HStack(spacing: SparkSpacing.xs) {
                SparkGlyph(item.icon, size: 13, relativeTo: .caption)
                    .foregroundStyle(item.tint)
                Text(item.title)
                    .font(SparkTypography.captionStrong)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: SparkSpacing.xs)
                if let daysAgo = item.daysAgo {
                    Text(MetricDisplay.dayLabel(daysAgo: daysAgo))
                        .font(SparkTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            hero

            if let line = contextLine {
                ComparisonText(comparison: item.comparison, text: line)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(SparkSpacing.lg)
        .sparkContentSurface(radius: SparkRadii.lg)
        .contentShape(RoundedRectangle(cornerRadius: SparkRadii.lg))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var hero: some View {
        if item.isScore, let latest = item.latest {
            ScoreRing(
                fraction: latest.value / 100,
                text: MetricDisplay.format(latest.value, unit: item.unit, action: item.metric.action).text,
                tint: item.tint,
                diameter: 64,
                valueColor: .sparkHero(domain: item.domain)
            )
            .frame(maxWidth: .infinity)
        } else if let value = item.value {
            HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.xs) {
                Text(value.text)
                    .font(SparkTypography.compactValue)
                    .foregroundStyle(Color.sparkHero(domain: item.domain))
                if let unit = value.unit {
                    Text(unit)
                        .font(SparkTypography.compactUnit)
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
    }

    /// The comparison, then the usual range it left.
    private var contextLine: String? {
        let parts = [item.comparison?.text, item.usualRange].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}

/// The comparison line (3.4): the arrow carries the polarity colour, the
/// words stay secondary.
private struct ComparisonText: View {
    let comparison: MetricComparison?
    let text: String

    private var arrowColor: Color {
        switch comparison?.isGood {
        case true?: .sparkSuccess
        case false?: .sparkError
        case nil: .secondary
        }
    }

    private var arrow: SparkIcon? {
        switch comparison?.direction {
        case .up?: .increase
        case .down?: .decrease
        case .steady?: .steady
        case nil: nil
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.xs) {
            if let arrow {
                SparkGlyph(arrow, size: 10, relativeTo: .caption)
                    .foregroundStyle(arrowColor)
            }
            Text(text)
                .font(SparkTypography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
}

extension MetricsExploreViewModel.LoadState: Equatable {
    static func == (lhs: MetricsExploreViewModel.LoadState, rhs: MetricsExploreViewModel.LoadState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.loaded, .loaded): return true
        case (.error(let l), .error(let r)): return l == r
        default: return false
        }
    }
}
