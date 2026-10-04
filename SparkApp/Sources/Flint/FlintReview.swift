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
            return chosenTransaction[item.id] != nil
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
                return
            }
            actionError = (error as? LocalizedError)?.errorDescription ?? "Couldn’t save that. Please try again."
        }
    }
}

struct FlintReviewSection: View {
    let model: FlintReviewModel

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            Text("Decisions Spark made by itself, and suggestions it wasn’t sure enough to act on.")
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
                    ForEach(model.items, id: \.reviewKey) { item in
                        FlintReviewCard(item: item, model: model)
                    }
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
}

private struct FlintReviewCard: View {
    let item: FlintReviewItem
    @Bindable var model: FlintReviewModel

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            HStack {
                Text(item.kind.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if let confidence = item.confidence {
                    Text("\(Int((confidence * 100).rounded()))% confident")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                if let createdAt = item.createdAt {
                    Text(createdAt, format: .dateTime.day().month())
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Text(item.title).font(.headline)
            Text(item.summary).font(.subheadline).foregroundStyle(.secondary)

            if item.kind == .receiptSuggestion {
                ForEach(item.candidates) { candidate in
                    Button {
                        model.chosenTransaction[item.id] = candidate.id
                    } label: {
                        HStack {
                            Image(systemName: model.chosenTransaction[item.id] == candidate.id ? "largecircle.fill.circle" : "circle")
                            Text(candidate.title ?? "Transaction")
                            Spacer()
                            Text(Self.amount(candidate)).foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(model.chosenTransaction[item.id] == candidate.id ? .isSelected : [])
                }
            } else if let linked = item.linked {
                HStack(spacing: SparkSpacing.xs) {
                    Text(item.subject.title ?? "Transaction")
                    Image(systemName: "arrow.right").accessibilityLabel("linked to")
                    Text(linked.title ?? "Transaction")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            HStack(spacing: SparkSpacing.sm) {
                ForEach(item.actions, id: \.self) { action in
                    Button(action.label) {
                        Task { await model.perform(action, on: item) }
                    }
                    .buttonStyle(.bordered)
                    .tint([.confirm, .keep].contains(action) ? Color.sparkAccent : Color.secondary)
                    .disabled(!model.canPerform(action, on: item))
                }
            }
        }
        .padding(SparkSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sparkGlass(.roundedRect(SparkRadii.lg))
    }

    private static func amount(_ event: FlintReviewEvent) -> String {
        guard let amount = event.amount else { return "" }
        guard let unit = event.unit else { return amount.formatted() }
        return amount.formatted(.currency(code: unit))
    }
}

private extension FlintReviewItem {
    var reviewKey: String { "\(kind.rawValue):\(id)" }
}
