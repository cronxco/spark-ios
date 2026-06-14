import MapKit
import SparkKit
import SparkUI
import SwiftUI

struct EventDetailView: View {
    let eventId: String
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: EventDetailViewModel?
    @State private var showNoteEditor = false

    private func aggregatedReferences(for detail: EventDetail) -> [EntityReference] {
        var seen = Set<String>()
        return detail.blocks
            .compactMap(\.references)
            .flatMap { $0 }
            .filter { seen.insert("\($0.type.rawValue):\($0.id)").inserted }
    }

    @ViewBuilder
    private func referencesSection(for detail: EventDetail) -> some View {
        EntityReferenceLinkRow(label: "Connecting", references: aggregatedReferences(for: detail))
    }
    @State private var noteDraft = ""
    @State private var noteError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                switch viewModel?.state {
                case .loaded(let detail):
                    content(for: detail)
                case .error(let msg):
                    EmptyState(
                        systemImage: "exclamationmark.triangle.fill",
                        title: "Couldn't load event",
                        message: msg,
                        actionTitle: "Retry"
                    ) { Task { await viewModel?.retry() } }
                default:
                    LoadingShimmerCard()
                    LoadingShimmerCard()
                }
            }
            .padding(.horizontal, SparkSpacing.lg)
            .padding(.top, SparkSpacing.xxl)
            .padding(.bottom, SparkSpacing.xl)
        }
        .sparkAppBackground()
        .navigationBarTitleDisplayMode(.inline)
        .sparkSubViewToolbar(
            shareItems: eventShareItems,
            rawTitle: "Raw event",
            rawPayload: eventRawPayload,
            feedbackContext: eventFeedbackContext,
            refresh: { await viewModel?.retry() }
        )
        .task(id: eventId) {
            if viewModel == nil {
                viewModel = EventDetailViewModel(eventId: eventId, apiClient: appModel.apiClient)
            }
            await viewModel?.load()
        }
    }

    @ViewBuilder
    private func content(for detail: EventDetail) -> some View {
        heroSection(for: detail)

        if let summary = detail.aiSummary, !summary.isEmpty {
            aiCalloutCard(summary)
        }

        if !detail.tags.isEmpty {
            FlowLayout(spacing: SparkSpacing.xs + 2) {
                ForEach(detail.tags) { tag in
                    let route = DetailRoute.tag(name: tag.name, type: tag.type)
                    NavigationLink(value: route) {
                        TagChip(tag)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            appModel.pendingRoute = .tag(name: tag.name, type: tag.type)
                        } label: {
                            Label("Open Tag", systemImage: "tag")
                        }
                    } preview: {
                        TagPreviewCard(tag: tag)
                            .environment(appModel)
                    }
                }
            }
        }

        metricBaselineStatusRow()

        if let loc = detail.location {
            eventMapCard(loc)
        }

        linkedObjectsSection(for: detail)

        referencesSection(for: detail)

        if !detail.blocks.isEmpty {
            blocksGrid(detail.blocks)
        }

        if !detail.related.isEmpty {
            relatedSection(detail.related)
        }

        noteSection(for: detail)
    }

    // MARK: - Cinematic hero

    private func heroSection(for detail: EventDetail) -> some View {
        SparkDetailHero(
            eyebrow: eyebrow(for: detail.event),
            status: nil,
            title: heroTitle(for: detail),
            subtitle: heroSubtitle(for: detail),
            value: displayValue(for: detail.event),
            valueTint: Color.domainTint(for: detail.event.domain),
            valueAlignment: .trailing
        )
    }

    private func eyebrow(for event: Event) -> String {
        var parts: [String] = [event.service.uppercased()]
        if let time = event.time {
            parts.append(SparkDetailFormatters.shortDate(time))
            parts.append(SparkDetailFormatters.shortTime(time))
        }
        return parts.joined(separator: " — ")
    }

    private func heroTitle(for detail: EventDetail) -> String {
        eventTitle(for: detail.event)
    }

    private func heroSubtitle(for detail: EventDetail) -> String? {
        if let tldr = detail.event.tldr, !tldr.isEmpty {
            return tldr
        }
        return nil
    }

    // MARK: - Linked objects

    @ViewBuilder
    private func linkedObjectsSection(for detail: EventDetail) -> some View {
        let links = linkedObjects(for: detail)
        if !links.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                SparkDetailSectionHeader("Objects", trailing: "\(links.count) linked")
                ForEach(links) { link in
                    NavigationLink {
                        ObjectDetailView(objectId: link.id)
                    } label: {
                        SparkDetailLinkedRow(
                            title: link.title,
                            subtitle: link.subtitle,
                            trailing: link.role
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func linkedObjects(for detail: EventDetail) -> [LinkedEventObject] {
        [
            linkedObject(from: detail.actor, role: "Actor"),
            linkedObject(from: detail.target, role: "Target")
        ].compactMap { $0 }
    }

    private func linkedObject(from object: EventDetail.ActorTarget?, role: String) -> LinkedEventObject? {
        guard let object, let id = object.id, !id.isEmpty else { return nil }
        let subtitle = [
            object.concept?.replacingOccurrences(of: "_", with: " "),
            object.type?.replacingOccurrences(of: "_", with: " ")
        ]
            .compactMap { value -> String? in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: " — ")
        return LinkedEventObject(
            id: id,
            role: role,
            title: object.title,
            subtitle: subtitle.isEmpty ? object.subtitle : subtitle
        )
    }

    // MARK: - AI summary callout

    private func aiCalloutCard(_ summary: String) -> some View {
        SparkDetailInsightCard(label: "Insight", text: summary, tint: Color.domainTint(for: "anomaly"))
    }

    // MARK: - Metric baseline

    @ViewBuilder
    private func metricBaselineStatusRow() -> some View {
        if let status = viewModel?.metricBaselineStatus {
            NavigationLink {
                MetricDetailView(identifier: status.metricIdentifier)
            } label: {
                metricBaselineStatusCard(status)
            }
            .buttonStyle(.plain)
        }
    }

    private func metricBaselineStatusCard(_ status: MetricBaselineStatus) -> some View {
        let tint = metricBaselineTint(for: status.state)
        return GlassCard(radius: SparkRadii.md, padding: SparkSpacing.md, tint: tint?.opacity(0.08)) {
            HStack(alignment: .center, spacing: SparkSpacing.md) {
                Text(status.title)
                    .font(SparkTypography.bodyStrong)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Spacer(minLength: SparkSpacing.sm)

                Text(status.trailing)
                    .font(SparkTypography.bodyStrong)
                    .foregroundStyle(tint ?? .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(status.title), \(status.trailing)")
    }

    private func metricBaselineTint(for state: MetricBaselineStatus.State) -> Color? {
        switch state {
        case .normal: nil
        case .high: .sparkError
        case .low: .sparkInfo
        }
    }

    // MARK: - Map

    private func eventMapCard(_ loc: EventDetail.Location) -> some View {
        let coordinate = CLLocationCoordinate2D(latitude: loc.lat, longitude: loc.lng)
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )
        return VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            SparkDetailSectionHeader("Location")

            Map(initialPosition: .region(region)) {
                Marker("", coordinate: coordinate)
                    .tint(Color.sparkAccent)
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: SparkRadii.lg))
            .overlay {
                RoundedRectangle(cornerRadius: SparkRadii.lg)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
            .allowsHitTesting(false)
        }
    }

    // MARK: - Blocks grid

    private func blocksGrid(_ blocks: [Block]) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            SparkDetailSectionHeader("Blocks", trailing: "\(blocks.count) blocks")
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: SparkSpacing.sm), GridItem(.flexible(), spacing: SparkSpacing.sm)],
                spacing: SparkSpacing.sm
            ) {
                ForEach(blocks) { block in
                    NavigationLink {
                        BlockDetailView(blockId: block.id)
                    } label: {
                        blockTile(block)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func blockTile(_ block: Block) -> some View {
        SparkDetailValueTile(
            label: block.blockType.replacingOccurrences(of: "_", with: " "),
            value: block.value?.sparkPlainTextFromHTMLFragment ?? block.title,
            subtitle: block.value == nil ? nil : block.title,
            tint: Color.sparkAccent
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(block.title), \(block.blockType.replacingOccurrences(of: "_", with: " "))")
    }

    // MARK: - Related events

    private func relatedSection(_ related: [EventDetail.RelatedEvent]) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            SparkDetailSectionHeader("Related")
            ForEach(related) { rel in
                SparkDetailLinkedRow(title: rel.title, subtitle: rel.meta, trailing: nil)
            }
        }
    }

    // MARK: - Notes

    private func noteSection(for detail: EventDetail) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            HStack {
                SectionLabel("Notes")
                Spacer(minLength: 0)
                Button {
                    noteDraft = detail.note ?? ""
                    noteError = nil
                    showNoteEditor = true
                } label: {
                    Label(detail.note?.isEmpty == false ? "Edit" : "Add", systemImage: "square.and.pencil")
                        .font(SparkTypography.captionStrong)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.sparkAccent)
            }

            if let note = detail.note, !note.isEmpty {
                GlassCard(radius: SparkRadii.md, padding: SparkSpacing.md) {
                    Text(note)
                        .font(SparkTypography.body)
                        .italic()
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                GlassCard(radius: SparkRadii.md, padding: SparkSpacing.md) {
                    Text("No note yet.")
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(isPresented: $showNoteEditor) {
            NavigationStack {
                VStack(alignment: .leading, spacing: SparkSpacing.md) {
                    TextEditor(text: $noteDraft)
                        .font(SparkTypography.body)
                        .frame(minHeight: 220)
                        .padding(SparkSpacing.sm)
                        .sparkGlass(.roundedRect(SparkRadii.md))

                    if let noteError {
                        Text(noteError)
                            .font(SparkTypography.caption)
                            .foregroundStyle(Color.sparkError)
                    }

                    Spacer(minLength: 0)
                }
                .padding(SparkSpacing.lg)
                .background(Color.sparkSurface.ignoresSafeArea())
                .navigationTitle(detail.note?.isEmpty == false ? "Edit note" : "Add note")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showNoteEditor = false
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("Close")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            Task { await saveNoteDraft() }
                        }
                    }
                }
            }
        }
    }

    private func saveNoteDraft() async {
        do {
            try await viewModel?.saveNote(noteDraft)
            showNoteEditor = false
        } catch {
            SparkObservability.captureHandled(error)
            noteError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    // MARK: - Raw metadata

    private var eventRawPayload: String? {
        guard case .loaded(let detail) = viewModel?.state else { return nil }
        if let rawPayload = viewModel?.rawPayload { return rawPayload }
        return SparkPrettyJSON.string(for: detail)
            ?? SparkPrettyJSON.fallback(
                entity: "event",
                id: detail.event.id,
                title: eventTitle(for: detail.event)
            )
    }

    private var eventFeedbackContext: SparkFeedbackContext {
        if case .loaded(let detail) = viewModel?.state {
            return SparkFeedbackContext(
                entityType: "event",
                entityId: detail.event.id,
                title: eventTitle(for: detail.event)
            )
        }
        return SparkFeedbackContext(entityType: "event", entityId: eventId, title: eventId)
    }

    private var eventShareItems: [Any] {
        guard case .loaded(let detail) = viewModel?.state else {
            return ["Spark Event: \(eventId)"]
        }
        if let url = detail.event.url.flatMap(URL.init) {
            return [url]
        }
        return [eventTitle(for: detail.event)]
    }

    private func formattedHeroValue(_ v: String, unit: String?) -> String {
        let plainValue = v.sparkPlainTextFromHTMLFragment
        guard let u = unit else { return plainValue }
        if plainValue.localizedCaseInsensitiveContains(u) {
            return plainValue
        }
        let currencyCodes = ["GBP", "USD", "EUR", "JPY"]
        if currencyCodes.contains(u.uppercased()), let amount = Double(plainValue.replacingOccurrences(of: ",", with: "")) {
            let fmt = NumberFormatter()
            fmt.numberStyle = .currency
            fmt.currencyCode = u
            fmt.maximumFractionDigits = 2
            return fmt.string(from: NSNumber(value: amount)) ?? "\(plainValue) \(u)"
        }
        return "\(plainValue) \(u)"
    }

    private func displayValue(for event: Event) -> String? {
        if let displayValue = event.displayValue?.sparkPlainTextFromHTMLFragment, !displayValue.isEmpty {
            return displayValue
        }
        return event.value.map { formattedHeroValue($0, unit: event.unit) }?.sparkPlainTextFromHTMLFragment
    }

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
}

private struct LinkedEventObject: Identifiable {
    let id: String
    let role: String
    let title: String
    let subtitle: String?
}
