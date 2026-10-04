import SparkKit
import SparkUI
import SwiftUI

/// History is independent of journey progress and never emits read signals.
struct RecapScreen: View {
    let viewModel: UpToSpeedViewModel
    var isActive = true
    @Environment(\.dismiss) private var dismiss

    private var days: [Date] {
        Set(viewModel.recapItems.map { Calendar.current.startOfDay(for: viewModel.recapDate(for: $0)) }).sorted(by: >)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                    Text("Take another look").font(SparkTypography.heroSmall)
                    Text("Revisit something you’ve seen, or restore it to your catch-up.")
                        .font(SparkTypography.body).foregroundStyle(.secondary)
                    if days.isEmpty { Text("Things you finish will appear here.").font(SparkTypography.body) }
                    ForEach(days, id: \.self) { day in
                        Text(day.formatted(.dateTime.weekday(.wide).day().month())).font(SparkTypography.bodyStrong)
                        GlassCard {
                            VStack(spacing: SparkSpacing.lg) {
                                ForEach(items(on: day)) { item in
                                    NavigationLink {
                                        RecapItemDetail(item: item, viewModel: viewModel)
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                                                Text(item.recapTitle).font(SparkTypography.bodyStrong)
                                                Text(viewModel.restoredIDs.contains(item.id) ? "Restored" : viewModel.recapDate(for: item).formatted(date: .omitted, time: .shortened))
                                                    .font(SparkTypography.caption).foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right").font(SparkTypography.caption)
                                        }
                                        .foregroundStyle(.primary).multilineTextAlignment(.leading)
                                        .frame(minHeight: 44)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(SparkSpacing.lg)
            }
            .background(Color.sparkSurface)
            .navigationTitle("Recap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .disabled(!viewModel.unmarkingIDs.isEmpty)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(!viewModel.unmarkingIDs.isEmpty)
    }

    private func items(on day: Date) -> [UpToSpeedItem] {
        viewModel.recapItems.filter { Calendar.current.isDate(viewModel.recapDate(for: $0), inSameDayAs: day) }
    }
}

private struct RecapItemDetail: View {
    let item: UpToSpeedItem
    let viewModel: UpToSpeedViewModel
    @Environment(AppModel.self) private var appModel
    @State private var digest: FlintDigest?
    @State private var event: EventDetail?
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var restoreError: String?

    var body: some View {
        Group {
            if case .newsSummary = item.payload {
                NewsSummaryScreen(item: item, isActive: false, onReachedBottom: nil, reserveTopSpace: false)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                        Text(item.recapTitle).font(SparkTypography.heroSmall)
                        detailContent
                        if isLoading { ProgressView("Loading detail…") }
                        if let loadError {
                            Text(loadError).font(SparkTypography.bodySmall).foregroundStyle(.secondary)
                            Button("Try again") { Task { await load() } }
                        }
                    }
                    .padding(SparkSpacing.lg)
                }
            }
        }
        .background(Color.sparkSurface)
        .navigationTitle("Recap")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { restoreControl }
        .task { await load() }
    }

    private var restoreControl: some View {
        VStack(spacing: SparkSpacing.sm) {
            if let restoreError { Text(restoreError).font(SparkTypography.bodySmall) }
            if case .checkIn = item.payload {
                Text("Completed check-in").font(SparkTypography.bodySmall)
            } else {
                Button {
                    Task {
                        restoreError = nil
                        if !(await viewModel.unmark(item)) { restoreError = "Couldn’t restore this item. Please try again." }
                    }
                } label: {
                    HStack {
                        if viewModel.unmarkingIDs.contains(item.id) { ProgressView() }
                        Text(viewModel.restoredIDs.contains(item.id) ? "Restored to your catch-up" : "Restore to catch-up")
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.unmarkingIDs.contains(item.id) || viewModel.restoredIDs.contains(item.id))
            }
        }
        .padding(SparkSpacing.lg)
        .background(Color.sparkSurface)
    }

    @ViewBuilder private var detailContent: some View {
        switch item.payload {
        case .flintDigest(let summary):
            if let text = digest?.summary ?? summary.summary {
                SparkLongFormContentView(text: text, tint: .sparkAccent, paragraphFont: SparkTypography.longFormBody)
            }
            ForEach(digest?.blocks ?? []) { block in
                if let context = block.dayContext {
                    DayContextSection(dayContext: context, yesterday: nil)
                } else {
                    GlassCard {
                        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                            Text(block.title).font(SparkTypography.bodyStrong)
                            if let text = block.content {
                                SparkLongFormContentView(text: text, tint: .sparkAccent, paragraphFont: SparkTypography.longFormBody)
                            }
                            if let question = block.question { Text(question).font(SparkTypography.body) }
                            if let answer = block.answer { Text(answer).font(SparkTypography.bodyStrong) }
                            if let note = block.answerNote { Text(note).font(SparkTypography.body) }
                            if let url = block.url.flatMap({ URL(string: $0) }) { Link("Open source", destination: url) }
                        }
                    }
                }
            }
        case .anomaly(let anomaly):
            if let value = anomaly.currentDisplay ?? anomaly.currentValue.map({ $0.formatted() }) { LabeledContent("Recorded value", value: value) }
            if let value = anomaly.baselineDisplay ?? anomaly.baselineValue.map({ $0.formatted() }) { LabeledContent("Usual value", value: value) }
            if let date = anomaly.detectedAt { Text(date.formatted()).font(SparkTypography.caption) }
        case .checkIn(let checkIn):
            Text(checkIn.date).font(SparkTypography.caption)
            ForEach(event?.blocks ?? []) { block in
                if let text = block.content {
                    SparkLongFormContentView(text: text, tint: .sparkAccent, paragraphFont: SparkTypography.longFormBody)
                }
            }
            if checkIn.eventId == nil { Text("No additional detail is available for this check-in.") }
        case .newsSummary: EmptyView()
        }
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            switch item.payload {
            case .flintDigest: digest = try await viewModel.recapDigest(for: item)
            case .checkIn(let checkIn):
                if let id = checkIn.eventId { event = try await appModel.apiClient.request(EventsEndpoint.detail(id: id)) }
            default: break
            }
        } catch where error.isAPICancellation {
        } catch { loadError = "Some detail couldn’t load. You can still read the available summary." }
    }
}

private extension UpToSpeedItem {
    var recapTitle: String {
        switch payload {
        case .flintDigest(let summary): summary.title ?? "Briefing"
        case .newsSummary(let news): news.title
        case .anomaly(let anomaly): anomaly.displayName ?? "Something unusual"
        case .checkIn(let summary): "\(summary.period.rawValue.capitalized) check-in"
        }
    }
}
