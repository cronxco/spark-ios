import Observation
import SparkKit
import SparkUI
import SwiftUI

/// Flint's Review queue: decisions Spark made by itself, and suggestions it
/// was not sure enough to act on (decisions E-1 and EX-D4).
@MainActor
@Observable
final class FlintReviewModel {
    enum State: Equatable {
        case idle, loading, loaded
        case error(String)
    }

    private(set) var items: [FlintReviewItem] = []
    private(set) var state: State = .idle
    var actionError: String?
    /// Items swiped away whose action is still in flight.
    private var pendingKeys: Set<String> = []
    /// Items acted on this session, so a slower response that predates the
    /// action can't bring one back.
    private var settledKeys: Set<String> = []

    let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func loadIfNeeded() async {
        guard state == .idle else { return }
        await load()
    }

    func load() async {
        state = .loading
        do {
            apply(try await apiClient.request(FlintEndpoint.review()).data)
            state = .loaded
        } catch where error.isAPICancellation {
            state = items.isEmpty ? .idle : .loaded
        } catch {
            SparkObservability.captureHandled(error)
            state = .error((error as? LocalizedError)?.errorDescription ?? "Couldn’t load the review queue.")
        }
    }

    func canPerform(_ action: FlintReviewAction, on item: FlintReviewItem) -> Bool {
        guard !pendingKeys.contains(item.reviewKey) else { return false }
        return action == item.acceptAction || action == item.rejectAction
    }

    /// Removes the item straight away, so a swipe feels instant, and puts it
    /// back if the server refuses.
    func perform(_ action: FlintReviewAction, on item: FlintReviewItem) async {
        guard canPerform(action, on: item),
              let index = items.firstIndex(where: { $0.reviewKey == item.reviewKey }) else { return }
        let key = item.reviewKey
        pendingKeys.insert(key)
        items.remove(at: index)

        let request = FlintReviewActionRequest(
            action: action,
            transactionID: action == .confirm && item.kind == .receiptSuggestion ? item.bestCandidate?.id : nil
        )
        do {
            let fresh = try await apiClient.request(FlintEndpoint.reviewAction(kind: item.kind, id: item.id, request)).data
            pendingKeys.remove(key)
            settledKeys.insert(key)
            apply(fresh)
        } catch where error.isAPICancellation {
            pendingKeys.remove(key)
            restore(item, at: index)
        } catch {
            pendingKeys.remove(key)
            SparkObservability.captureHandled(error)
            if case APIError.httpStatus(404, _, _) = error {
                settledKeys.insert(key)
                actionError = "That item is no longer available. The list has been refreshed."
                return
            }
            if case APIError.httpStatus(422, _, _) = error {
                await load()
            } else {
                restore(item, at: index)
            }
            actionError = (error as? LocalizedError)?.errorDescription ?? "Couldn’t save that. Please try again."
        }
    }

    private func apply(_ fresh: [FlintReviewItem]) {
        items = fresh.filter { !pendingKeys.contains($0.reviewKey) && !settledKeys.contains($0.reviewKey) }
    }

    private func restore(_ item: FlintReviewItem, at index: Int) {
        guard !items.contains(where: { $0.reviewKey == item.reviewKey }) else { return }
        items.insert(item, at: min(index, items.count))
    }
}

/// The Review tab. A `List` rather than a scroll view so each row gets the
/// system's full swipe: swipe right to accept, left to reject.
struct FlintReviewSection: View {
    let model: FlintReviewModel
    @State private var showingUnmatched = false

    var body: some View {
        List {
            switch model.state {
            case .idle where model.items.isEmpty, .loading where model.items.isEmpty:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            case .error(let message) where model.items.isEmpty:
                VStack(spacing: SparkSpacing.md) {
                    EmptyState(systemImage: "wifi.exclamationmark", title: "Couldn’t load review", message: message)
                    PillButton("Retry", systemImage: "arrow.clockwise", tint: .sparkAccent) {
                        Task { await model.load() }
                    }
                }
                .listRowBackground(Color.clear)
            default:
                if model.items.isEmpty {
                    EmptyState(systemImage: "checkmark.circle", title: "Nothing to review", message: "Spark has nothing waiting for you.")
                        .listRowBackground(Color.clear)
                } else {
                    reviewGroup("To decide", items: model.items.filter(\.needsDecision))
                    reviewGroup("Linked by Spark", items: model.items.filter { !$0.needsDecision })
                }
            }

            Section {
                Button {
                    showingUnmatched = true
                } label: {
                    Label("Unmatched receipts", systemImage: "doc.text.magnifyingglass")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .animation(.default, value: model.items.map(\.reviewKey))
        .sheet(isPresented: $showingUnmatched) {
            NavigationStack {
                ReceiptUnmatchedView(apiClient: model.apiClient)
                    .sparkDetailDestinations()
            }
        }
        .alert("Couldn’t save", isPresented: Binding(
            get: { model.actionError != nil },
            set: { if !$0 { model.actionError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.actionError ?? "Please try again.")
        }
    }

    @ViewBuilder
    private func reviewGroup(_ title: String, items: [FlintReviewItem]) -> some View {
        if !items.isEmpty {
            Section {
                ForEach(items, id: \.reviewKey) { item in
                    FlintReviewRow(item: item, model: model)
                }
            } header: {
                Text("\(title) (\(items.count))")
            }
        }
    }
}

/// One decision on one line: the receipt or first transaction on the left,
/// what it is (or would be) linked to on the right.
private struct FlintReviewRow: View {
    let item: FlintReviewItem
    let model: FlintReviewModel
    @State private var showingReceiptMatch = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isReceipt: Bool { item.kind == .receiptSuggestion || item.kind == .receiptAutoMatch }

    var body: some View {
        Group {
            if isReceipt {
                Button { showingReceiptMatch = true } label: { pairing }
                    .buttonStyle(.plain)
            } else {
                // A hidden link keeps the row free of the disclosure chevron,
                // which would squeeze the right-hand side.
                pairing.background {
                    NavigationLink(value: DetailRoute.event(id: item.subject.id)) { EmptyView() }
                        .opacity(0)
                }
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if let accept = item.acceptAction {
                Button {
                    Task { await model.perform(accept, on: item) }
                } label: {
                    Label(accept.label, systemImage: "checkmark")
                }
                .tint(.sparkSuccess)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if let reject = item.rejectAction {
                Button {
                    Task { await model.perform(reject, on: item) }
                } label: {
                    Label(reject.label, systemImage: "xmark")
                }
                .tint(.sparkError)
            }
        }
        .contextMenu {
            NavigationLink(value: DetailRoute.event(id: item.subject.id)) {
                Label(isReceipt ? "Open receipt" : "Open transaction", systemImage: "arrow.up.forward.app")
            }
            if let counterpart = item.counterpart {
                NavigationLink(value: DetailRoute.event(id: counterpart.id)) {
                    Label(isReceipt ? "Open transaction" : "Open linked transaction", systemImage: "arrow.up.forward.app")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityActions {
            if let accept = item.acceptAction {
                Button(accept.label) { Task { await model.perform(accept, on: item) } }
            }
            if let reject = item.rejectAction {
                Button(reject.label) { Task { await model.perform(reject, on: item) } }
            }
        }
        .sheet(isPresented: $showingReceiptMatch, onDismiss: {
            Task { await model.load() }
        }) {
            NavigationStack {
                ReceiptMatchingView(receiptID: item.subject.id, apiClient: model.apiClient)
                    .sparkDetailDestinations()
            }
        }
    }

    private var pairing: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: SparkSpacing.sm))
            : AnyLayout(HStackLayout(alignment: .center, spacing: SparkSpacing.sm))
        return layout {
            FlintReviewSide(event: item.subject, alignment: .leading)
            score
            if let counterpart = item.counterpart {
                FlintReviewSide(event: counterpart, alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing)
            } else {
                Text("No match")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing)
            }
        }
        .contentShape(Rectangle())
    }

    private var score: some View {
        VStack(spacing: 2) {
            Image(systemName: "link")
            if let confidence = item.counterpartConfidence {
                Text(confidence, format: .percent.precision(.fractionLength(0)))
                    .monospacedDigit()
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var accessibilityDescription: String {
        var parts = ["\(FlintReviewSide.title(item.subject)), \(FlintReviewSide.value(item.subject))"]
        if let counterpart = item.counterpart {
            parts.append("linked to \(FlintReviewSide.title(counterpart)), \(FlintReviewSide.value(counterpart))")
        } else {
            parts.append("no match")
        }
        if let confidence = item.counterpartConfidence {
            parts.append("\(Int((confidence * 100).rounded()))% match")
        }
        return parts.joined(separator: ", ")
    }
}

private struct FlintReviewSide: View {
    let event: FlintReviewEvent
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(Self.title(event))
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text(Self.value(event))
                .font(.subheadline)
                .monospacedDigit()
            if let time = event.time {
                Text(time, format: .dateTime.day().month(.abbreviated).hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(alignment == .trailing ? .trailing : .leading)
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
    }

    static func title(_ event: FlintReviewEvent) -> String {
        event.title.flatMap { $0.isEmpty ? nil : $0 } ?? "Untitled"
    }

    static func value(_ event: FlintReviewEvent) -> String {
        guard let amount = event.amount else { return "No amount" }
        guard let unit = event.unit, unit.count == 3 else {
            return "\(amount.formatted())\(event.unit.map { " \($0)" } ?? "")"
        }
        return amount.formatted(.currency(code: unit.uppercased()))
    }
}

struct FlintReviewEventCard: View {
    let event: FlintReviewEvent
    let role: String

    private var title: String { event.title.flatMap { $0.isEmpty ? nil : $0 } ?? "Untitled event" }

    private var value: String {
        guard let amount = event.amount else { return "No value recorded" }
        guard let unit = event.unit, unit.count == 3 else {
            return "\(amount.formatted())\(event.unit.map { " \($0)" } ?? "")"
        }
        return amount.formatted(.currency(code: unit.uppercased()))
    }

    private var reference: EntityReference {
        EntityReference(type: .event, id: event.id, title: title, service: event.service, domain: "money")
    }

    var body: some View {
        NavigationLink(value: DetailRoute.event(id: event.id)) {
            content
                .padding(SparkSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.sparkElevated, in: RoundedRectangle(cornerRadius: SparkRadii.md))
                .overlay(RoundedRectangle(cornerRadius: SparkRadii.md).strokeBorder(Color.primary.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .contextMenu {
            NavigationLink(value: DetailRoute.event(id: event.id)) {
                Label("Open event", systemImage: "arrow.up.forward.app")
            }
        } preview: {
            EntityPreviewCard(reference: reference)
        }
        .accessibilityLabel("View \(role): \(title), \(value), \(event.service?.capitalized ?? "unknown source"), \(dateLabel)")
    }

    private var dateLabel: String {
        event.time?.formatted(date: .abbreviated, time: .shortened) ?? "time not recorded"
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.xs) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.sm) {
                    roleLabel
                    Spacer(minLength: SparkSpacing.xs)
                    valueLabel
                }
                VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                    roleLabel
                    valueLabel
                }
            }
            Text(title)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text(dateLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var roleLabel: some View {
        Text("\(role) · \(event.service?.capitalized ?? "Unknown source")")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var valueLabel: some View {
        Text(value)
            .font(.subheadline.weight(.medium))
            .multilineTextAlignment(.trailing)
    }
}
