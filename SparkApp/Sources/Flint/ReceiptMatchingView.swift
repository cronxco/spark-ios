import Observation
import SparkKit
import SparkUI
import SwiftUI

@MainActor
@Observable
final class ReceiptMatchingModel {
    private let apiClient: APIClient
    private let receiptID: String
    private(set) var receipt: ReceiptMatch?
    private(set) var transactions: [FlintReviewEvent] = []
    private(set) var loading = false
    private(set) var busy = false
    var error: String?

    init(receiptID: String, apiClient: APIClient) {
        self.receiptID = receiptID
        self.apiClient = apiClient
    }

    func load() async {
        loading = true
        defer { loading = false }
        do {
            receipt = try await apiClient.request(FlintEndpoint.receiptMatch(id: receiptID)).data
        } catch where error.isAPICancellation {
            return
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Couldn’t load this receipt."
        }
    }

    func search(_ query: String) async {
        do {
            transactions = try await apiClient.request(
                FlintEndpoint.receiptTransactions(id: receiptID, query: query)
            ).data
        } catch where error.isAPICancellation {
            return
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Couldn’t search transactions."
        }
    }

    func retry() async {
        await perform { try await apiClient.request(FlintEndpoint.retryReceiptMatch(id: receiptID)).data }
    }

    func link(to transactionID: String) async {
        await perform {
            try await apiClient.request(FlintEndpoint.linkReceipt(id: receiptID, transactionID: transactionID)).data
        }
    }

    func markUnmatched() async {
        await perform { try await apiClient.request(FlintEndpoint.markReceiptUnmatched(id: receiptID)).data }
    }

    func unlink() async {
        await perform { try await apiClient.request(FlintEndpoint.unlinkReceipt(id: receiptID)).data }
    }

    private func perform(_ action: () async throws -> ReceiptMatch) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            receipt = try await action()
            if receipt?.status == "matched" { transactions = [] }
        } catch where error.isAPICancellation {
            return
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Couldn’t update the match."
            await load()
        }
    }
}

struct ReceiptMatchingView: View {
    @State private var model: ReceiptMatchingModel
    @State private var searchText = ""

    init(receiptID: String, apiClient: APIClient) {
        _model = State(initialValue: ReceiptMatchingModel(receiptID: receiptID, apiClient: apiClient))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SparkSpacing.md) {
                if model.loading && model.receipt == nil {
                    ProgressView("Loading receipt…")
                } else if let receipt = model.receipt {
                    Text(statusLabel(receipt.status))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    FlintReviewEventCard(event: receipt.reviewEvent, role: "Receipt")
                    if let attemptedAt = receipt.attemptedAt {
                        Text("Last searched \(attemptedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let matched = receipt.matched {
                        Text("Linked transaction").font(.headline)
                        FlintReviewEventCard(event: matched, role: "Transaction")
                        Button("Remove match", role: .destructive) { Task { await model.unlink() } }
                            .disabled(model.busy)
                    } else {
                        Button("Find match again") { Task { await model.retry() } }
                            .disabled(model.busy || receipt.status == "searching")
                        if receipt.status == "searching" {
                            Text("Searching for a transaction…").foregroundStyle(.secondary)
                        }
                        if !receipt.candidates.isEmpty {
                            Text("Suggested transactions").font(.headline)
                            ForEach(receipt.candidates) { candidate in
                                transactionRow(candidate, label: "Confirm match")
                            }
                        }
                        Text("Search transactions").font(.headline)
                        TextField("Merchant, amount or YYYY-MM-DD", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Search transactions")
                        ForEach(model.transactions) { transaction in
                            transactionRow(transaction, label: "Link transaction")
                        }
                        Button("No matching transaction") { Task { await model.markUnmatched() } }
                            .buttonStyle(.bordered)
                            .disabled(model.busy)
                    }
                } else if let error = model.error {
                    EmptyState(systemImage: "wifi.exclamationmark", title: "Couldn’t load receipt", message: error)
                    Button("Retry") { Task { await model.load() } }
                }
            }
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(SparkSpacing.lg)
        }
        .navigationTitle("Receipt matching")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
        .task(id: searchText) {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await model.search(searchText)
        }
        .refreshable { await model.load() }
        .alert("Couldn’t update receipt", isPresented: Binding(
            get: { model.error != nil && model.receipt != nil },
            set: { if !$0 { model.error = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.error ?? "Please try again.")
        }
    }

    private func transactionRow(_ event: FlintReviewEvent, label: String) -> some View {
        VStack(alignment: .leading, spacing: SparkSpacing.xs) {
            FlintReviewEventCard(event: event, role: "Transaction")
            Button(label) { Task { await model.link(to: event.id) } }
                .buttonStyle(.borderedProminent)
                .disabled(model.busy)
        }
    }

    private func statusLabel(_ status: String) -> String {
        switch status {
        case "matched": "Matched"
        case "suggestions": "Suggestions available"
        case "searching": "Searching"
        case "needs_details": "Needs receipt details"
        case "no_candidate": "No match found"
        case "no_match": "Marked as having no match"
        case "failed": "Matching failed"
        default: "Unmatched"
        }
    }
}

struct ReceiptUnmatchedView: View {
    let apiClient: APIClient
    @State private var receipts: [ReceiptMatch] = []
    @State private var page = 0
    @State private var lastPage = 1
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SparkSpacing.md) {
                Text("Receipts without a linked transaction, newest first.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ForEach(receipts) { receipt in
                    NavigationLink {
                        ReceiptMatchingView(receiptID: receipt.id, apiClient: apiClient)
                    } label: {
                        VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                            Text(receipt.title ?? "Receipt").font(.headline)
                            Text("\(receipt.time?.formatted(date: .abbreviated, time: .shortened) ?? "Time unknown") · \(receipt.status.replacingOccurrences(of: "_", with: " "))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(SparkSpacing.md)
                        .sparkGlass(.roundedRect(SparkRadii.md))
                    }
                    .buttonStyle(.plain)
                }
                if page < lastPage {
                    Button("Load more") { Task { await load(page: page + 1) } }
                        .disabled(loading)
                }
                if loading { ProgressView() }
                if let error { Text(error).foregroundStyle(.secondary) }
            }
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(SparkSpacing.lg)
        }
        .navigationTitle("Unmatched receipts")
        .task { await load(page: 1) }
        .refreshable { await load(page: 1) }
    }

    private func load(page nextPage: Int) async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do {
            let response = try await apiClient.request(FlintEndpoint.unmatchedReceipts(page: nextPage))
            receipts = nextPage == 1 ? response.data : receipts + response.data
            page = nextPage
            lastPage = response.meta?.lastPage ?? nextPage
            error = nil
        } catch where error.isAPICancellation {
            return
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Couldn’t load unmatched receipts."
        }
    }
}

private extension ReceiptMatch {
    var reviewEvent: FlintReviewEvent {
        FlintReviewEvent(id: id, title: title, amount: amount, unit: unit, time: time, service: service)
    }
}
