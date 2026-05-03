import MapKit
import SparkKit
import SparkUI
import SwiftUI

struct EventDetailView: View {
    let eventId: String
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: EventDetailViewModel?
    @State private var showShareSheet = false
    @State private var showDeleteConfirm = false
    @State private var showMetadata = false
    @State private var showNoteEditor = false
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
            .padding(.vertical, SparkSpacing.lg)
        }
        .background(Color.sparkSurface.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
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
            TagChipRow(detail.tags)
        }

        if let loc = detail.location {
            eventMapCard(loc)
        }

        if !detail.blocks.isEmpty {
            blocksGrid(detail.blocks)
        }

        if !detail.related.isEmpty {
            relatedSection(detail.related)
        }

        noteSection(for: detail)

        quickActionsBar(for: detail)

        metadataButton(for: detail)
    }

    // MARK: - Cinematic hero

    private func heroSection(for detail: EventDetail) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                Text(eyebrow(for: detail.event))
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .lineLimit(1)

                Text(detail.event.action.humanisedAction)
                    .font(SparkTypography.bodySmall)
                    .foregroundStyle(.secondary)

                if let actor = detail.actor {
                    Text(actor.title)
                        .font(SparkFonts.display(.title, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }

                if let target = detail.target {
                    Text(target.title)
                        .font(SparkTypography.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let value = detail.event.value {
                    let display = formattedHeroValue(value, unit: detail.event.unit)
                    Text(display)
                        .font(SparkFonts.display(.largeTitle, weight: .bold))
                        .foregroundStyle(Color.domainTint(for: detail.event.domain))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.top, SparkSpacing.xs)
                }
            }
        }
    }

    private func eyebrow(for event: Event) -> String {
        var parts: [String] = [event.service.uppercased()]
        if let time = event.time {
            parts.append(Self.dateFormatter.string(from: time))
            parts.append(Self.timeFormatter.string(from: time))
        }
        return parts.joined(separator: " — ")
    }

    // MARK: - AI summary callout

    private func aiCalloutCard(_ summary: String) -> some View {
        GlassCard(tint: Color.sparkAccent.opacity(0.06)) {
            HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.sm) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(Color.sparkAccent)
                Text(summary)
                    .font(SparkTypography.bodySmall)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Insight: \(summary)")
    }

    // MARK: - Map

    private func eventMapCard(_ loc: EventDetail.Location) -> some View {
        let coordinate = CLLocationCoordinate2D(latitude: loc.lat, longitude: loc.lng)
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )
        return Map(initialPosition: .region(region)) {
            Marker("", coordinate: coordinate)
                .tint(Color.sparkAccent)
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: SparkRadii.lg))
        .allowsHitTesting(false)
    }

    // MARK: - Blocks grid

    private func blocksGrid(_ blocks: [Block]) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            SectionLabel("Linked blocks (\(blocks.count))")
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
        GlassCard(radius: SparkRadii.md, padding: SparkSpacing.md) {
            VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                Text(block.blockType.replacingOccurrences(of: "_", with: " "))
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .lineLimit(1)
                Text(block.title)
                    .font(SparkTypography.bodySmall)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                if let value = block.value {
                    Text(value)
                        .font(SparkTypography.bodyStrong)
                        .foregroundStyle(Color.sparkAccent)
                        .lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(block.title), \(block.blockType.replacingOccurrences(of: "_", with: " "))")
    }

    // MARK: - Related events

    private func relatedSection(_ related: [EventDetail.RelatedEvent]) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            SectionLabel("Related")
            ForEach(related) { rel in
                GlassCard(radius: SparkRadii.md, padding: SparkSpacing.md) {
                    HStack(spacing: SparkSpacing.md) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rel.title)
                                .font(SparkTypography.bodySmall)
                            if let meta = rel.meta {
                                Text(meta)
                                    .font(SparkTypography.monoSmall)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
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
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showNoteEditor = false }
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

    private func metadataButton(for detail: EventDetail) -> some View {
        Button {
            showMetadata = true
        } label: {
            HStack(spacing: SparkSpacing.sm) {
                Image(systemName: "curlybraces")
                    .font(.caption)
                Text("Raw metadata")
                    .font(SparkTypography.bodySmall)
                Spacer(minLength: 0)
                Text(detail.event.id)
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(.secondary)
            .padding(SparkSpacing.md)
            .sparkGlass(.roundedRect(SparkRadii.md))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showMetadata) {
            ScrollView {
                Text(prettyMetadata(for: detail))
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(SparkSpacing.md)
            }
            .frame(minWidth: 320, minHeight: 320)
            .presentationCompactAdaptation(.sheet)
        }
    }

    private func prettyMetadata(for detail: EventDetail) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        if let metadata = detail.metadata,
           let data = try? encoder.encode(metadata),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        if let data = try? encoder.encode([detail]),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "[]"
    }
    // MARK: - Quick actions bar

    private func quickActionsBar(for detail: EventDetail) -> some View {
        HStack(spacing: SparkSpacing.sm) {
            quickAction(icon: "bookmark", label: "Bookmark") {}
            quickAction(icon: "square.and.arrow.up", label: "Share") {
                showShareSheet = true
            }
            quickAction(icon: "tag", label: "Tag") {}
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = detail.event.url.flatMap(URL.init) {
                ShareSheet(items: [url])
            } else {
                ShareSheet(items: [detail.event.action.humanisedAction])
            }
        }
    }

    private func quickAction(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(label)
                    .font(SparkTypography.monoSmall)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SparkSpacing.sm)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .sparkGlass(.roundedRect(SparkRadii.md))
    }

    // MARK: - Formatters

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let fullTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd  HH:mm:ss ZZZZZ"
        return f
    }()

    private func formattedHeroValue(_ v: String, unit: String?) -> String {
        guard let u = unit else { return v }
        let currencyCodes = ["GBP", "USD", "EUR", "JPY"]
        if currencyCodes.contains(u.uppercased()), let amount = Double(v) {
            let fmt = NumberFormatter()
            fmt.numberStyle = .currency
            fmt.currencyCode = u
            fmt.maximumFractionDigits = 2
            return fmt.string(from: NSNumber(value: amount)) ?? "\(v) \(u)"
        }
        return "\(v) \(u)"
    }
}

// MARK: - Domain tint

extension Color {
    static func domainTint(for domain: String) -> Color {
        switch domain.lowercased() {
        case "health": .domainHealth
        case "activity": .domainActivity
        case "money": .domainMoney
        case "media": .domainMedia
        case "knowledge": .domainKnowledge
        case "anomaly": .domainAnomaly
        default: .sparkAccent
        }
    }
}

// MARK: - Share sheet bridge

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
