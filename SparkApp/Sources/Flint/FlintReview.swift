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
    private(set) var pendingItemID: String?
    var actionError: String?
    /// The candidate transaction picked for each receipt suggestion.
    var chosenTransaction: [String: String] = [:]

    private let apiClient: APIClient

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
            items = try await apiClient.request(FlintEndpoint.review()).data
            state = .loaded
        } catch where error.isAPICancellation {
            state = items.isEmpty ? .idle : .loaded
        } catch {
            SparkObservability.captureHandled(error)
            state = .error((error as? LocalizedError)?.errorDescription ?? "Couldn’t load the review queue.")
        }
    }

    func canPerform(_ action: FlintReviewAction, on item: FlintReviewItem) -> Bool {
        guard pendingItemID == nil else { return false }
        if item.kind == .receiptSuggestion, action == .confirm {
            return item.candidates.contains { $0.id == chosenTransaction[item.id] }
        }
        return true
    }

    func perform(_ action: FlintReviewAction, on item: FlintReviewItem) async {
        guard canPerform(action, on: item) else { return }
        pendingItemID = item.id
        defer { pendingItemID = nil }

        let request = FlintReviewActionRequest(
            action: action,
            transactionID: action == .confirm ? chosenTransaction[item.id] : nil
        )
        do {
            items = try await apiClient.request(FlintEndpoint.reviewAction(kind: item.kind, id: item.id, request)).data
            let remaining = Set(items.map(\.id))
            chosenTransaction = chosenTransaction.filter { remaining.contains($0.key) }
        } catch where error.isAPICancellation {
            return
        } catch {
            SparkObservability.captureHandled(error)
            if case APIError.httpStatus(404, _, _) = error {
                items.removeAll { $0.id == item.id && $0.kind == item.kind }
                actionError = "That item is no longer available. The list has been refreshed."
                return
            }
            if case APIError.httpStatus(422, _, _) = error {
                await load()
            }
            actionError = (error as? LocalizedError)?.errorDescription ?? "Couldn’t save that. Please try again."
        }
    }
}

struct FlintReviewSection: View {
    let model: FlintReviewModel

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            Text("Decide on suggestions first. Spark’s automatic links remain available to undo for 30 days.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            switch model.state {
            case .idle where model.items.isEmpty, .loading where model.items.isEmpty:
                ProgressView("Loading review…")
                    .frame(maxWidth: .infinity)
            case .error(let message) where model.items.isEmpty:
                VStack(spacing: SparkSpacing.md) {
                    EmptyState(systemImage: "wifi.exclamationmark", title: "Couldn’t load review", message: message)
                    PillButton("Retry", systemImage: "arrow.clockwise", tint: .sparkAccent) {
                        Task { await model.load() }
                    }
                }
            default:
                if model.items.isEmpty {
                    EmptyState(systemImage: "checkmark.circle", title: "Nothing to review", message: "Spark has nothing waiting for you.")
                } else {
                    reviewGroup("Needs your decision", items: model.items.filter(\.needsDecision))
                    reviewGroup("Linked by Spark", items: model.items.filter { !$0.needsDecision })
                }
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
            VStack(alignment: .leading, spacing: SparkSpacing.md) {
                Text("\(title) (\(items.count))")
                    .font(.title3.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                ForEach(items, id: \.reviewKey) { item in
                    FlintReviewCard(item: item, model: model)
                }
            }
        }
    }
}

private struct FlintReviewCard: View {
    let item: FlintReviewItem
    @Bindable var model: FlintReviewModel
    @State private var showingUndoConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            HStack(alignment: .top) {
                Text(item.kind.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if let confidence = item.confidence {
                    Text("\(Int((confidence * 100).rounded()))% match score")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let createdAt = item.createdAt, item.kind != .receiptSuggestion {
                    Text("\(item.needsDecision ? "Suggested" : "Linked") \(createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(item.summary).font(.subheadline).foregroundStyle(.secondary)

            FlintReviewEventCard(
                event: item.subject,
                role: item.kind == .receiptSuggestion || item.kind == .receiptAutoMatch ? "Receipt" : "First transaction"
            )

            if let linked = item.linked {
                FlintReviewEventCard(
                    event: linked,
                    role: item.kind == .receiptAutoMatch ? "Transaction" : "Linked transaction"
                )
            }

            if item.kind == .receiptSuggestion {
                if item.candidates.isEmpty {
                    Text("No suggested transactions are available now. You can dismiss this suggestion.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Choose a transaction")
                        .font(.subheadline.weight(.semibold))
                    ForEach(item.candidates) { candidate in
                        HStack(alignment: .center, spacing: SparkSpacing.sm) {
                            Button {
                                model.chosenTransaction[item.id] = candidate.id
                            } label: {
                                Image(systemName: model.chosenTransaction[item.id] == candidate.id ? "largecircle.fill.circle" : "circle")
                                    .font(.title3)
                                    .frame(minWidth: 44, minHeight: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Select \(candidate.title ?? "transaction")")
                            .accessibilityAddTraits(model.chosenTransaction[item.id] == candidate.id ? .isSelected : [])

                            FlintReviewEventCard(
                                event: candidate,
                                role: "Candidate · \(Int(((candidate.confidence ?? 0) * 100).rounded()))% match score"
                            )
                        }
                    }
                }
            } else if let relationshipType = item.relationshipType {
                Text("Relationship: \(relationshipType.replacingOccurrences(of: "_", with: " "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: SparkSpacing.sm) {
                ForEach(item.actions.filter { $0 != .keep }, id: \.self) { action in
                    Button(action.label) {
                        if action == .undo {
                            showingUndoConfirmation = true
                        } else {
                            Task { await model.perform(action, on: item) }
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(action == .confirm ? Color.sparkAccent : Color.secondary)
                    .disabled(!model.canPerform(action, on: item))
                }
            }
        }
        .padding(SparkSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sparkGlass(.roundedRect(SparkRadii.lg))
        .confirmationDialog("Undo this automatic link?", isPresented: $showingUndoConfirmation) {
            Button("Undo link", role: .destructive) {
                Task { await model.perform(.undo, on: item) }
            }
        } message: {
            Text("The two events will be unlinked.")
        }
    }
}

private struct FlintReviewEventCard: View {
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

private extension FlintReviewItem {
    var reviewKey: String { "\(kind.rawValue):\(id)" }
    var needsDecision: Bool { kind == .receiptSuggestion || kind == .linkSuggestion }
}
