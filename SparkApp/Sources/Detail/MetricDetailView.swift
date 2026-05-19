import SparkKit
import SparkUI
import SwiftUI

@MainActor
@Observable
final class MetricDetailViewModel {
    let identifier: String
    var range: MetricsEndpoint.Range
    private(set) var state: DetailLoadState<MetricDetail> = .loading
    private(set) var recentEvents: [Event] = []
    private(set) var rawPayload: String?

    private let apiClient: APIClient

    init(identifier: String, range: MetricsEndpoint.Range = .thirtyDays, apiClient: APIClient) {
        self.identifier = identifier
        self.range = range
        self.apiClient = apiClient
    }

    func load() async {
        state = .loading
        recentEvents = []
        let canonicalIdentifier = MetricsEndpoint.canonicalIdentifier(identifier)
        guard MetricIdentifier.split(canonicalIdentifier) != nil else {
            state = .error("Metric unavailable.")
            return
        }
        do {
            let response = try await apiClient.requestWithRawResponse(
                MetricsEndpoint.detail(identifier: canonicalIdentifier, range: range)
            )
            let detail = response.decoded
            rawPayload = response.utf8Body
            state = .loaded(detail)
            recentEvents = await fetchRecentEvents(for: detail)
        } catch APIError.notModified {
            return
        } catch where error.isAPICancellation {
            return
        } catch APIError.httpStatus(404, _, _) {
            state = .error("Metric unavailable.")
        } catch {
            SparkObservability.captureHandled(error)
            let msg = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            state = .error(msg)
        }
    }

    func setRange(_ newRange: MetricsEndpoint.Range) async {
        guard newRange != range else { return }
        range = newRange
        await load()
    }

    private func fetchRecentEvents(for detail: MetricDetail) async -> [Event] {
        guard let parts = MetricIdentifier.split(detail.id) else { return [] }

        var cursor: String?
        var matches: [Event] = []
        var pagesFetched = 0

        repeat {
            do {
                let page = try await apiClient.request(
                    FeedEndpoint.feed(
                        cursor: cursor,
                        limit: 100,
                        domain: detail.domain
                    )
                )
                matches.append(contentsOf: page.data.filter { event in
                    event.service == parts.service && event.action == parts.action
                })
                cursor = page.hasMore ? page.nextCursor : nil
                pagesFetched += 1
            } catch APIError.notModified {
                return matches
            } catch where error.isAPICancellation {
                return matches
            } catch {
                SparkObservability.captureHandled(error)
                return matches
            }
        } while cursor != nil && matches.count < 10 && pagesFetched < 3

        return Array(matches.prefix(10))
    }
}

struct MetricAnomalyRowModel: Equatable, Sendable, Identifiable {
    enum State: Equatable, Sendable {
        case high
        case low
        case unknown
    }

    let id: String
    let title: String
    let subtitle: String
    let trailing: String?
    let state: State
    let eventId: String?

    static func make(
        anomaly: MetricDetail.AnomalyPoint,
        detail: MetricDetail,
        recentEvents: [Event],
        calendar: Calendar = .current
    ) -> MetricAnomalyRowModel {
        let value = detail.valueForAnomaly(anomaly)
        let state = state(value: value, baseline: detail.baseline)
        let eventId = matchingEvent(for: anomaly, in: recentEvents, calendar: calendar)?.id

        return MetricAnomalyRowModel(
            id: anomaly.id,
            title: title(for: state),
            subtitle: formatDate(anomaly.date),
            trailing: value.map { format(value: $0, unit: detail.unit) },
            state: state,
            eventId: eventId
        )
    }

    private static func state(value: Double?, baseline: MetricDetail.Baseline?) -> State {
        guard let value, let baseline else { return .unknown }
        let low = max(0, baseline.low)
        if value > baseline.high { return .high }
        if value < low { return .low }
        return .unknown
    }

    private static func title(for state: State) -> String {
        switch state {
        case .high: "Above Normal Range"
        case .low: "Below Normal Range"
        case .unknown: "Outside Normal Range"
        }
    }

    private static func matchingEvent(
        for anomaly: MetricDetail.AnomalyPoint,
        in events: [Event],
        calendar: Calendar
    ) -> Event? {
        events.first { event in
            guard let time = event.time else { return false }
            return calendar.isDate(time, inSameDayAs: anomaly.date)
        }
    }

    private static func format(value: Double, unit: String?) -> String {
        let formatted = formatNumber(value)
        guard let unit, !unit.isEmpty else { return formatted }
        return "\(formatted) \(unit)"
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    private static func formatNumber(_ value: Double) -> String {
        let absValue = abs(value)
        if absValue >= 100 || absValue == floor(absValue) {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}

struct MetricDetailView: View {
    let identifier: String
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: MetricDetailViewModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                switch viewModel?.state {
                case .loaded(let detail):
                    content(for: detail)
                case .error(let msg):
                    EmptyState(
                        systemImage: "exclamationmark.triangle.fill",
                        title: "Couldn't load metric",
                        message: msg,
                        actionTitle: "Retry"
                    ) { Task { await viewModel?.load() } }
                default:
                    LoadingShimmerCard()
                    LoadingShimmerCard()
                }
            }
            .padding(SparkSpacing.lg)
        }
        .sparkAppBackground()
        .navigationTitle("Metric")
        .navigationBarTitleDisplayMode(.inline)
        .sparkSubViewToolbar(
            shareItems: metricShareItems,
            rawTitle: "Raw metric",
            rawPayload: metricRawPayload,
            feedbackContext: metricFeedbackContext,
            refresh: { await viewModel?.load() }
        )
        .task(id: identifier) {
            if viewModel == nil {
                viewModel = MetricDetailViewModel(
                    identifier: identifier,
                    apiClient: appModel.apiClient
                )
            }
            await viewModel?.load()
        }
    }

    private var metricShareItems: [Any] {
        guard case .loaded(let detail) = viewModel?.state else {
            return ["Spark Metric: \(identifier)"]
        }
        return ["Spark Metric: \(detail.title)"]
    }

    private var metricRawPayload: String? {
        guard case .loaded(let detail) = viewModel?.state else { return nil }
        if let rawPayload = viewModel?.rawPayload { return rawPayload }
        return SparkPrettyJSON.string(for: detail)
            ?? SparkPrettyJSON.fallback(entity: "metric", id: detail.id, title: detail.title)
    }

    private var metricFeedbackContext: SparkFeedbackContext {
        if case .loaded(let detail) = viewModel?.state {
            return SparkFeedbackContext(
                entityType: "metric",
                entityId: detail.id,
                title: detail.title
            )
        }
        return SparkFeedbackContext(entityType: "metric", entityId: identifier, title: identifier)
    }

    @ViewBuilder
    private func content(for detail: MetricDetail) -> some View {
        heroSection(detail)
        rangePicker(detail)
        chartCard(detail)
        legend(detail)
        if let compares = detail.compares, !compares.isEmpty {
            compareSection(compares)
        }
        anomalyList(detail)
        recentEventsSection(detail)
    }

    // MARK: - Hero

    private func heroSection(_ detail: MetricDetail) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            SectionLabel("\(detail.domain) · \(detail.id)")
            Text(detail.title)
                .font(SparkFonts.display(.title, weight: .bold))
                .accessibilityAddTraits(.isHeader)

            HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.lg) {
                if let today = detail.today {
                    Text(format(value: today, unit: detail.unit))
                        .font(SparkFonts.display(.largeTitle, weight: .bold))
                        .foregroundStyle(Color.domainTint(for: detail.domain))
                        .accessibilityLabel("Today \(format(value: today, unit: detail.unit))")
                }

                VStack(alignment: .leading, spacing: 2) {
                    if let avg = detail.average30d, let today = detail.today {
                        Text(deltaLabel(today: today, average: avg))
                            .font(SparkTypography.bodySmall)
                            .foregroundStyle(today >= avg ? Color.sparkSuccess : Color.sparkWarning)
                    }
                    if let avg = detail.average30d {
                        Text("30d avg \(format(value: avg, unit: detail.unit))")
                            .font(SparkTypography.monoSmall)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }

    private func deltaLabel(today: Double, average: Double) -> String {
        let diff = today - average
        let sign = diff >= 0 ? "+" : ""
        return "\(sign)\(formatNumber(diff)) vs avg"
    }

    // MARK: - Range picker

    private func rangePicker(_ detail: MetricDetail) -> some View {
        let bound = Binding<MetricsEndpoint.Range>(
            get: { viewModel?.range ?? .thirtyDays },
            set: { newValue in Task { await viewModel?.setRange(newValue) } }
        )

        return Picker("Range", selection: bound) {
            ForEach(MetricsEndpoint.Range.allCases, id: \.self) { range in
                Text(range.label).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Date range")
    }

    // MARK: - Chart

    private func chartCard(_ detail: MetricDetail) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                MetricTrendChart(
                    series: detail.series,
                    baseline: detail.baseline,
                    anomalies: detail.anomalies,
                    valueForAnomaly: { detail.valueForAnomaly($0) },
                    tint: Color.domainTint(for: detail.domain)
                )
            }
        }
    }

    private func legend(_ detail: MetricDetail) -> some View {
        HStack(spacing: SparkSpacing.lg) {
            HStack(spacing: SparkSpacing.xs + 2) {
                Rectangle()
                    .fill(Color.domainTint(for: detail.domain))
                    .frame(width: 14, height: 2)
                Text(detail.title.lowercased())
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
            }
            if detail.baseline != nil {
                HStack(spacing: SparkSpacing.xs + 2) {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(.secondary.opacity(0.4),
                                style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                        .frame(width: 14, height: 8)
                    Text("baseline")
                        .font(SparkTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if !detail.anomalies.isEmpty {
                HStack(spacing: SparkSpacing.xs + 2) {
                    Circle()
                        .fill(Color.sparkWarning)
                        .frame(width: 8, height: 8)
                    Text("anomaly")
                        .font(SparkTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Compare grid

    private func compareSection(_ compares: [MetricDetail.Compare]) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            SectionLabel("Compare")
            HStack(spacing: SparkSpacing.sm) {
                ForEach(compares.prefix(3)) { compare in
                    GlassCard(radius: SparkRadii.md, padding: SparkSpacing.md) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(compare.label.uppercased())
                                .font(SparkTypography.monoSmall)
                                .foregroundStyle(.secondary)
                            Text(formatNumber(compare.value))
                                .font(SparkFonts.display(.title3, weight: .bold))
                            if let delta = compare.delta {
                                Text("\(delta >= 0 ? "+" : "")\(formatNumber(delta))")
                                    .font(SparkTypography.captionStrong)
                                    .foregroundStyle(delta >= 0 ? Color.sparkSuccess : Color.sparkWarning)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Anomalies list

    @ViewBuilder
    private func anomalyList(_ detail: MetricDetail) -> some View {
        if !detail.anomalies.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                SectionLabel("Recent anomalies")
                ForEach(detail.anomalies) { anomaly in
                    let row = MetricAnomalyRowModel.make(
                        anomaly: anomaly,
                        detail: detail,
                        recentEvents: viewModel?.recentEvents ?? []
                    )
                    if let eventId = row.eventId {
                        NavigationLink {
                            EventDetailView(eventId: eventId)
                        } label: {
                            anomalyRow(row)
                        }
                        .buttonStyle(.plain)
                    } else {
                        anomalyRow(row)
                    }
                }
            }
        }
    }

    private func anomalyRow(_ row: MetricAnomalyRowModel) -> some View {
        let tint = anomalyTint(for: row.state)
        return GlassCard(radius: SparkRadii.md, padding: SparkSpacing.md, tint: tint?.opacity(0.08)) {
            HStack(alignment: .center, spacing: SparkSpacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title)
                        .font(SparkTypography.bodySmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text(row.subtitle)
                        .font(SparkTypography.monoSmall)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if let trailing = row.trailing {
                    Text(trailing)
                        .font(SparkTypography.bodyStrong)
                        .foregroundStyle(tint ?? Color.domainTint(for: "anomaly"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                if row.eventId != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel([row.title, row.subtitle, row.trailing].compactMap { $0 }.joined(separator: ", "))
    }

    private func anomalyTint(for state: MetricAnomalyRowModel.State) -> Color? {
        switch state {
        case .high: .sparkError
        case .low: .sparkInfo
        case .unknown: nil
        }
    }

    // MARK: - Recent events

    @ViewBuilder
    private func recentEventsSection(_ detail: MetricDetail) -> some View {
        let events = viewModel?.recentEvents ?? []
        if !events.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                SparkDetailSectionHeader("Recent Events", trailing: "\(events.count)")
                ForEach(events) { event in
                    NavigationLink {
                        EventDetailView(eventId: event.id)
                    } label: {
                        SparkDetailLinkedRow(
                            title: eventTitle(for: event),
                            subtitle: eventSubtitle(for: event),
                            trailing: displayValue(for: event),
                            tint: Color.domainTint(for: detail.domain)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Formatting

    private func eventTitle(for event: Event) -> String {
        let action = event.action.sparkActionTitle
        guard event.displayWithObject,
              let target = event.target?.title.trimmingCharacters(in: .whitespacesAndNewlines),
              !target.isEmpty
        else {
            return action
        }
        return "\(action) \(target)"
    }

    private func eventSubtitle(for event: Event) -> String? {
        var parts: [String] = [event.service.uppercased()]
        if let time = event.time {
            parts.append(SparkDetailFormatters.compactDateTime.string(from: time))
        }
        return parts.joined(separator: " - ")
    }

    private func displayValue(for event: Event) -> String? {
        if let displayValue = event.displayValue?.sparkPlainTextFromHTMLFragment, !displayValue.isEmpty {
            return displayValue
        }
        return event.value.map { formattedEventValue($0, unit: event.unit) }?.sparkPlainTextFromHTMLFragment
    }

    private func formattedEventValue(_ value: String, unit: String?) -> String {
        let plainValue = value.sparkPlainTextFromHTMLFragment
        guard let unit else { return plainValue }
        if plainValue.localizedCaseInsensitiveContains(unit) {
            return plainValue
        }
        return "\(plainValue) \(unit)"
    }

    private func format(value: Double, unit: String?) -> String {
        let formatted = formatNumber(value)
        guard let unit, !unit.isEmpty else { return formatted }
        return "\(formatted) \(unit)"
    }

    private func formatNumber(_ value: Double) -> String {
        let absValue = abs(value)
        if absValue >= 100 || absValue == floor(absValue) {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()
}
