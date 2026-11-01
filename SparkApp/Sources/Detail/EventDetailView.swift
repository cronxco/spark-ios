import MapKit
import SparkKit
import SparkUI
import SwiftUI

struct EventDetailView: View {
    let eventId: String
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: EventDetailViewModel?
    @State private var showNoteEditor = false
    @State private var showTagPicker = false
    @State private var tagPendingRemoval: EventTag?
    @State private var tagMutationError: String?
    @State private var showEditor = false
    @State private var showLocationEditor = false
    @State private var confirmDelete = false
    @State private var relationships = RelationshipsStore()
    @State private var showOtherSummaries = false

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
            .padding(.bottom, SparkSpacing.xxl)
        }
        .sparkDetailInlineTitle(inlineTitle)
        .sparkAppBackground()
        .sparkOnscreenEntity(
            type: "event",
            identifier: eventId,
            title: onscreenTitle,
            subtitle: onscreenSubtitle
        )
        .sparkSubViewToolbar(
            shareItems: eventShareItems,
            rawTitle: "Raw event",
            rawPayload: eventRawPayload,
            feedbackContext: eventFeedbackContext,
            refresh: { await viewModel?.retry() },
            flintNoteContext: .event(id: eventId, label: onscreenTitle),
            edit: SparkSubViewMenuAction(title: "Edit event", isEnabled: isLoaded) { showEditor = true },
            location: SparkSubViewMenuAction(title: hasLocation ? "Edit location" : "Add location", isEnabled: isLoaded) { showLocationEditor = true },
            delete: SparkSubViewMenuAction(title: "Delete event", isEnabled: isLoaded) { confirmDelete = true },
            details: eventInfo
        )
        .sparkRelationshipsHost(relationships, kind: .events, entityID: eventId, apiClient: appModel.apiClient) { request in
            guard let viewModel else { throw TagMutationError.missingETag }
            return try await viewModel.createRelationship(request)
        }
        .sparkDeleteWithUndo(
            noun: "event",
            isDeleted: viewModel?.isDeleted == true,
            isConfirming: $confirmDelete,
            delete: { try await viewModel?.delete() },
            restore: { try await viewModel?.restore() }
        )
        .task(id: eventId) {
            if viewModel == nil {
                viewModel = EventDetailViewModel(eventId: eventId, apiClient: appModel.apiClient)
            }
            await viewModel?.load()
        }
        .sheet(isPresented: $showTagPicker) {
            TagPickerSheet { request in
                try await viewModel?.attachTag(request)
            }
        }
        .sheet(isPresented: $showEditor) { if case .loaded(let detail) = viewModel?.state { EntityEditorSheet(title: "Event", initial: ["action": detail.event.action, "value": detail.event.value ?? "", "value_multiplier": "", "value_unit": detail.event.unit ?? "", "time": detail.event.time?.ISO8601Format() ?? ""]) { try await viewModel?.update($0) } } }
        .sheet(isPresented: $showLocationEditor) { LocationEditorSheet(hasLocation: hasLocation, geocode: { try await viewModel?.geocode(address: $0) }, coordinates: { try await viewModel?.setLocation($0) }, clear: { try await viewModel?.clearLocation() }) }
        .confirmationDialog(
            "Remove tag?",
            isPresented: Binding(get: { tagPendingRemoval != nil }, set: { if !$0 { tagPendingRemoval = nil } })
        ) {
            Button("Remove tag", role: .destructive) {
                guard let tag = tagPendingRemoval else { return }
                Task { await detach(tag) }
            }
        } message: {
            Text("This removes the tag from this event.")
        }
        .alert("Couldn't update tags", isPresented: Binding(get: { tagMutationError != nil }, set: { if !$0 { tagMutationError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(tagMutationError ?? "Please try again.")
        }
    }

    // Onscreen context advertised to Siri ("tell me more about this").
    private var onscreenTitle: String {
        if case .loaded(let detail) = viewModel?.state {
            return detail.target?.title
                ?? detail.event.displayName
                ?? "\(detail.event.action.replacingOccurrences(of: "_", with: " ").capitalized)"
        }
        return "Event"
    }

    private var hasLocation: Bool {
        if case .loaded(let detail) = viewModel?.state { return detail.location != nil }
        return false
    }

    /// Passed to block screens so they can link back before the API sends it.
    private var loadedEvent: Event? {
        if case .loaded(let detail) = viewModel?.state { return detail.event }
        return nil
    }

    private var inlineTitle: String {
        if case .loaded(let detail) = viewModel?.state { return heroTitle(for: detail.event) }
        return ""
    }

    private var isLoaded: Bool {
        if viewModel?.isDeleted == true { return false }
        if case .loaded = viewModel?.state { return true }
        return false
    }

    private var onscreenSubtitle: String? {
        if case .loaded(let detail) = viewModel?.state {
            return detail.aiSummary?.isEmpty == false ? detail.aiSummary : detail.event.service.capitalized
        }
        return nil
    }

    /// Content first, then what it's about, then anything added to it. Empty
    /// tags, relationships and notes don't get a section; the Add row at the
    /// end offers them instead.
    @ViewBuilder
    private func content(for detail: EventDetail) -> some View {
        heroSection(for: detail)

        // Generated text adds to the event, so it takes the card, not the
        // band (§3.5).
        if let summary = detail.aiSummary, !summary.isEmpty {
            SparkDetailSummaryCard(text: summary)
        }

        flowSection(for: detail)

        if detail.hasRoute {
            EventRouteSection(eventID: detail.id, apiClient: appModel.apiClient)
        } else if let loc = detail.location {
            eventMapCard(loc)
        }

        if !detail.blocks.isEmpty {
            blocksSection(detail.blocks, domain: detail.event.domain, service: detail.event.service)
        }

        referencesSection(for: detail)

        if !detail.related.isEmpty {
            relatedSection(detail.related)
        }

        if !detail.tags.isEmpty {
            tagSection(for: detail)
        }

        if relationships.hasContent {
            RelationshipsSection(
                store: relationships,
                kind: .events,
                entityID: detail.id,
                apiClient: appModel.apiClient,
                delete: { relationship in
                    guard let viewModel else { throw TagMutationError.missingETag }
                    try await viewModel.deleteRelationship(relationship)
                }
            )
        }

        if let note = detail.note, !note.isEmpty {
            noteSection(note)
        }

        addRow(for: detail)
            .sheet(isPresented: $showNoteEditor) { noteEditor(for: detail) }
    }

    private func addRow(for detail: EventDetail) -> some View {
        var actions = [
            SparkDetailAddRow.Action(title: "Tag", systemImage: "tag") { showTagPicker = true }
        ]
        if detail.note?.isEmpty != false {
            actions.append(SparkDetailAddRow.Action(title: "Note", systemImage: "square.and.pencil") {
                noteDraft = ""
                noteError = nil
                showNoteEditor = true
            })
        }
        actions.append(SparkDetailAddRow.Action(title: "Link", systemImage: "link") { relationships.isAdding = true })
        return SparkDetailAddRow(actions: actions)
    }

    private func tagSection(for detail: EventDetail) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            SparkDetailSectionHeader("Tags", icon: .tag)
            FlowLayout(spacing: SparkSpacing.xs + 2) {
                ForEach(detail.tags) { tag in
                    DetailTagChip(tag: tag)
                        .contextMenu {
                            Button(role: .destructive) { tagPendingRemoval = tag } label: {
                                Label("Remove tag", systemImage: "trash")
                            }
                        } preview: {
                            TagPreviewCard(tag: tag).environment(appModel)
                        }
                }
            }
        }
    }

    private func detach(_ tag: EventTag) async {
        do {
            try await viewModel?.detachTag(tag)
        } catch {
            tagMutationError = (error as? LocalizedError)?.errorDescription ?? "Please try again."
        }
        tagPendingRemoval = nil
    }

    // MARK: - Hero

    /// The verb, then the thing the event is about, then its value (§12.2).
    /// A 0–100 score is a ring; anything else is the 56pt value.
    private func heroSection(for detail: EventDetail) -> some View {
        let event = detail.event
        let target = heroTargetTitle(for: event)
        return SparkDetailCentredHero(
            icon: EntityPresentation.icon(domain: event.domain, service: event.service, action: event.action, type: "event"),
            domain: event.domain,
            verb: target == nil ? nil : event.action.sparkActionTitle,
            title: heroTitle(for: event),
            subtitle: heroSubtitle(for: detail),
            value: heroValue(for: event),
            source: event.service.sparkSentenceCase,
            time: event.time
        ) {
            heroComparison(for: event)
        }
    }

    private func heroValue(for event: Event) -> SparkDetailHeroValue {
        let number = SparkDetailNumber.parse(event.value)
        if SparkDetailNumber.isScore(value: number, unit: event.unit), let number {
            return .score(
                number,
                text: SparkDetailNumber.format(number, unit: nil),
                threshold: event.service.lowercased() == "oura" ? 0.85 : nil
            )
        }
        if let text = displayValue(for: event), !text.isEmpty {
            return .text(text)
        }
        return .hidden
    }

    /// "↑ 3 above 30d trend", against the metric this event is a reading
    /// of. A tap opens the metric.
    private func heroComparison(for event: Event) -> AnyView {
        guard let metric = viewModel?.metric,
              let average = metric.average30d,
              let value = SparkDetailNumber.parse(event.value)
        else { return AnyView(EmptyView()) }
        let comparison = SparkDetailComparison.make(value: value, average: average, unit: event.unit ?? metric.unit, domain: event.domain)
        let line = SparkDetailComparisonLine(comparison: comparison)
        guard let identifier = viewModel?.metricIdentifier else { return AnyView(line) }
        return AnyView(
            NavigationLink {
                MetricDetailView(identifier: identifier)
            } label: {
                line
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens \(metric.title)")
        )
    }

    /// The thing the event is about leads ("The Diplomat S04E02"), with the
    /// verb as the status line ("Watched episode"). Gluing the two together
    /// read as "Watched Episode The Diplomat S04E02".
    private func heroTitle(for event: Event) -> String {
        heroTargetTitle(for: event) ?? eventTitle(for: event)
    }

    private func heroTargetTitle(for event: Event) -> String? {
        guard event.displayWithObject,
              let target = event.target?.title.trimmingCharacters(in: .whitespacesAndNewlines),
              !target.isEmpty
        else { return nil }
        return target
    }

    private func heroSubtitle(for detail: EventDetail) -> String? {
        if let tldr = detail.event.tldr, !tldr.isEmpty {
            return tldr
        }
        return nil
    }

    // MARK: - Flow

    /// Actor, then the event, then its target, always, even when the actor
    /// is you (§12.2).
    private func flowSection(for detail: EventDetail) -> some View {
        let event = detail.event
        return SparkDetailFlowSection(
            actor: detail.actor.map(party(for:)),
            action: event.action.sparkActionTitle,
            value: displayValue(for: event),
            domain: event.domain,
            icon: EntityPresentation.icon(domain: event.domain, service: event.service, action: event.action, type: "event"),
            target: detail.target.map(party(for:))
        )
    }

    private func party(for object: EventDetail.ActorTarget) -> SparkDetailFlowSection.Party {
        SparkDetailFlowSection.Party(
            id: object.id,
            title: object.title,
            typeName: object.isAccountOwner ? "You" : object.typeName,
            type: object.type ?? object.concept
        )
    }

    // MARK: - Map

    private func eventMapCard(_ loc: EventDetail.Location) -> some View {
        let coordinate = CLLocationCoordinate2D(latitude: loc.lat, longitude: loc.lng)
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )
        return VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            SparkDetailSectionHeader("Location", icon: .place)

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

    // MARK: - Blocks

    /// Takeaways read inline, other text blocks are rows with a preview, the
    /// alternative summaries fold away (the hero already shows the tl;dr), and
    /// only blocks with a numeric value keep the tile grid.
    @ViewBuilder
    private func blocksSection(_ blocks: [Block], domain: String, service: String) -> some View {
        let groups = BlockGroups(blocks)

        if !groups.contributors.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                SparkDetailSectionHeader("Contributors", count: groups.contributors.count, icon: .chart)
                SparkDetailContributorList(
                    blocks: groups.contributors,
                    domain: domain,
                    threshold: service.lowercased() == "oura" ? 0.85 : nil,
                    parent: loadedEvent
                )
            }
        }

        ForEach(groups.takeaways) { block in
            NavigationLink {
                BlockDetailView(blockId: block.id, parent: loadedEvent)
            } label: {
                BlockCard(block, size: .card)
            }
            .buttonStyle(.plain)
        }

        if !groups.rows.isEmpty || !groups.summaries.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                SparkDetailSectionHeader("Blocks", count: groups.rows.count + groups.summaries.count, icon: .grid)
                ForEach(groups.rows) { block in blockRow(block) }

                if !groups.summaries.isEmpty {
                    Button {
                        withAnimation(.snappy) { showOtherSummaries.toggle() }
                    } label: {
                        HStack(spacing: SparkSpacing.xs) {
                            Text(groups.rows.isEmpty ? "Summaries" : "Other summaries")
                            Text("\(groups.summaries.count)").foregroundStyle(.secondary)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                                .rotationEffect(.degrees(showOtherSummaries ? 0 : -90))
                        }
                        .font(SparkTypography.captionStrong)
                        .foregroundStyle(Color.sparkAccent)
                        .padding(.vertical, SparkSpacing.xs)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showOtherSummaries ? "Hide summaries" : "Show \(groups.summaries.count) summaries")

                    if showOtherSummaries {
                        ForEach(groups.summaries) { block in blockRow(block) }
                    }
                }
            }
        }

        if !groups.values.isEmpty {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: SparkSpacing.sm), GridItem(.flexible(), spacing: SparkSpacing.sm)],
                spacing: SparkSpacing.sm
            ) {
                ForEach(groups.values) { block in
                    NavigationLink {
                        BlockDetailView(blockId: block.id, parent: loadedEvent)
                    } label: {
                        BlockCard(block, size: .compact)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func blockRow(_ block: Block) -> some View {
        NavigationLink {
            BlockDetailView(blockId: block.id, parent: loadedEvent)
        } label: {
            BlockCard(block, size: .row)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Related events

    private func relatedSection(_ related: [EventDetail.RelatedEvent]) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            SparkDetailSectionHeader("Related", count: related.count, icon: .duration)
            ForEach(related) { rel in
                NavigationLink {
                    EventDetailView(eventId: rel.id)
                } label: {
                    SparkDetailLinkedRow(title: rel.title, subtitle: relatedSubtitle(for: rel), trailing: nil)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func relatedSubtitle(for rel: EventDetail.RelatedEvent) -> String? {
        let time = rel.time.map { SparkDetailFormatters.compactDateTime.string(from: $0) }
        let parts = [rel.meta, time].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    // MARK: - Notes

    private func noteSection(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                SparkDetailSectionHeader("Note", icon: .edit)
                Spacer(minLength: 0)
                Button {
                    noteDraft = note
                    noteError = nil
                    showNoteEditor = true
                } label: {
                    Label("Edit", systemImage: "square.and.pencil")
                        .font(SparkTypography.captionStrong)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.sparkAccent)
            }

            GlassCard(radius: SparkRadii.md, padding: SparkSpacing.md) {
                Text(note)
                    .font(SparkTypography.body)
                    .italic()
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func noteEditor(for detail: EventDetail) -> some View {
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

    private func saveNoteDraft() async {
        do {
            try await viewModel?.saveNote(noteDraft)
            showNoteEditor = false
        } catch {
            SparkObservability.captureHandled(error)
            noteError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    // MARK: - Details sheet

    private var eventInfo: SparkDetailInfo? {
        guard case .loaded(let detail) = viewModel?.state else { return nil }
        let event = detail.event
        var rows = [
            SparkDetailInfo.Row(key: "Integration", value: event.service.sparkSentenceCase),
            SparkDetailInfo.Row(key: "Type", value: event.action.sparkActionTitle),
        ]
        if let time = event.time {
            rows.append(SparkDetailInfo.Row(key: "Recorded", value: SparkDetailDateText.full(time)))
        }
        rows.append(SparkDetailInfo.Row(key: "Event ID", value: event.id, isMono: true, isCopyable: true))
        return SparkDetailInfo(
            rows: rows,
            openTitle: "Open in \(event.service.sparkSentenceCase)",
            openURL: event.url.flatMap(URL.init(string:))
        )
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

/// Sorts an event's blocks by how the detail screen shows them. Which
/// group a block lands in comes from its `BlockKind`; how it looks there is
/// `BlockCard`'s job.
struct BlockGroups {
    var contributors = [Block]()
    var takeaways = [Block]()
    var rows = [Block]()
    var summaries = [Block]()
    var values = [Block]()

    init(_ blocks: [Block]) {
        for block in blocks {
            if SparkDetailContributorList.isContributor(block) {
                contributors.append(block)
                continue
            }
            if let value = block.value, !value.isEmpty {
                values.append(block)
                continue
            }
            switch block.kind {
            case .takeaways where block.content?.isEmpty == false:
                takeaways.append(block)
            case .aiSummary:
                summaries.append(block)
            default:
                rows.append(block)
            }
        }
    }
}
