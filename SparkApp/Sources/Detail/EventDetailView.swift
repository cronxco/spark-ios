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
            location: SparkSubViewMenuAction(title: hasLocation ? "Edit location" : "Add location", isEnabled: isLoaded) { showLocationEditor = true },
            delete: SparkSubViewMenuAction(title: "Delete event", isEnabled: isLoaded) { confirmDelete = true }
        )
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Edit") { showEditor = true }.disabled(!isLoaded) } }
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

        if let summary = detail.aiSummary, !summary.isEmpty {
            aiCalloutCard(summary)
        }

        metricBaselineStatusRow()

        if detail.hasRoute {
            EventRouteSection(eventID: detail.id, apiClient: appModel.apiClient)
        } else if let loc = detail.location {
            eventMapCard(loc)
        }

        if !detail.blocks.isEmpty {
            blocksSection(detail.blocks)
        }

        aboutSection(for: detail)

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
            SparkDetailSectionHeader("Tags")
            FlowLayout(spacing: SparkSpacing.xs + 2) {
                ForEach(detail.tags) { tag in
                    let route = DetailRoute.tag(id: tag.tagID, name: tag.name, type: tag.type)
                    NavigationLink(value: route) { TagChip(tag) }
                        .buttonStyle(.plain)
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

    // MARK: - Cinematic hero

    private func heroSection(for detail: EventDetail) -> some View {
        SparkDetailHero(
            eyebrow: eyebrow(for: detail.event),
            status: heroTargetTitle(for: detail.event) == nil ? nil : detail.event.action.sparkSentenceCase,
            title: heroTitle(for: detail.event),
            subtitle: heroSubtitle(for: detail),
            value: displayValue(for: detail.event),
            valueTint: Color.domainTint(for: detail.event.domain),
            valueAlignment: .trailing
        )
    }

    private func eyebrow(for event: Event) -> String {
        var parts: [String] = [event.service.sparkSentenceCase]
        if let time = event.time {
            parts.append(SparkDetailFormatters.shortDate.string(from: time))
            parts.append(SparkDetailFormatters.shortTime.string(from: time))
        }
        return parts.joined(separator: " — ")
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

    // MARK: - About

    /// What the event is about, and who it was with when that isn't you.
    /// The account owner's own user object is the actor on nearly every
    /// event, so it's left out rather than shown as "Actor" every time.
    @ViewBuilder
    private func aboutSection(for detail: EventDetail) -> some View {
        let links = linkedObjects(for: detail)
        if !links.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                SparkDetailSectionHeader("About")
                ForEach(links) { link in
                    NavigationLink {
                        ObjectDetailView(objectId: link.id)
                    } label: {
                        SparkDetailLinkedRow(
                            title: link.title,
                            subtitle: link.subtitle,
                            trailing: nil,
                            tint: Color.domainTint(for: detail.event.domain),
                            icon: link.icon
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func linkedObjects(for detail: EventDetail) -> [LinkedEventObject] {
        let title = heroTitle(for: detail.event)
        var links = [LinkedEventObject]()
        if let target = detail.target, let id = target.id, !id.isEmpty {
            // When the hero already names the target, the row says what kind
            // of thing it is instead of repeating the title.
            let repeatsHero = target.title.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(title) == .orderedSame
            links.append(LinkedEventObject(
                id: id,
                title: repeatsHero ? target.typeName : target.title,
                subtitle: repeatsHero ? nil : target.typeName,
                icon: ObjectTypeGlyph.symbol(type: target.type, concept: target.concept)
            ))
        }
        if let actor = detail.actor, let id = actor.id, !id.isEmpty, !actor.isAccountOwner, id != detail.target?.id {
            links.append(LinkedEventObject(
                id: id,
                title: actor.title,
                subtitle: actor.typeName,
                icon: ObjectTypeGlyph.symbol(type: actor.type, concept: actor.concept)
            ))
        }
        return links
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

    // MARK: - Blocks

    /// Takeaways read inline, other text blocks are rows with a preview, the
    /// alternative summaries fold away (the hero already shows the tl;dr), and
    /// only blocks with a numeric value keep the tile grid.
    @ViewBuilder
    private func blocksSection(_ blocks: [Block]) -> some View {
        let groups = BlockGroups(blocks)

        ForEach(groups.takeaways) { block in
            NavigationLink {
                BlockDetailView(blockId: block.id, parent: loadedEvent)
            } label: {
                GlassCard(radius: SparkRadii.lg, padding: SparkSpacing.lg) {
                    VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                        SectionLabel(block.title, style: .dayHeading)
                        SparkLongFormContentView(text: block.content ?? "", paragraphFont: SparkTypography.body)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
        }

        if !groups.rows.isEmpty || !groups.summaries.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                SparkDetailSectionHeader("Content", trailing: "\(groups.rows.count + groups.summaries.count) blocks")
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
                        SparkDetailValueTile(
                            label: block.title,
                            value: block.value?.sparkPlainTextFromHTMLFragment ?? "",
                            subtitle: block.unit,
                            tint: Color.sparkAccent
                        )
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
            SparkDetailBlockRow(title: block.title, preview: BlockGroups.preview(for: block))
        }
        .buttonStyle(.plain)
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

    private func noteSection(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel("Notes", style: .dayHeading)
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
    let title: String
    let subtitle: String?
    let icon: String
}

/// Sorts an event's blocks by how the detail screen shows them.
struct BlockGroups {
    var takeaways = [Block]()
    var rows = [Block]()
    var summaries = [Block]()
    var values = [Block]()

    init(_ blocks: [Block]) {
        for block in blocks {
            let type = block.blockType.lowercased()
            if let value = block.value, !value.isEmpty {
                values.append(block)
            } else if type.contains("takeaway"), block.content?.isEmpty == false {
                takeaways.append(block)
            } else if type.contains("summary") || type.contains("tldr") {
                summaries.append(block)
            } else {
                rows.append(block)
            }
        }
    }

    /// The first couple of lines of a block's text, without markup.
    static func preview(for block: Block) -> String? {
        guard let content = block.content?.sparkPlainTextFromHTMLFragment else { return nil }
        let collapsed = content
            .replacingOccurrences(of: "[#*_>`]", with: "", options: .regularExpression)
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !collapsed.isEmpty else { return nil }
        return collapsed.count > 220 ? String(collapsed.prefix(220)) + "…" : collapsed
    }
}
