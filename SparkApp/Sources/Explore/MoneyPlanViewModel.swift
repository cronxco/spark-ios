import Foundation
import Observation
import OSLog
import SparkKit

/// Amounts from the money plan endpoints are integer pence.
enum MoneyPlanFormat {
    static func pounds(_ pence: Int, signed: Bool = false) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = pence % 100 == 0 ? 0 : 2
        formatter.maximumFractionDigits = 2
        let body = formatter.string(from: NSNumber(value: Double(abs(pence)) / 100)) ?? "0"
        let sign = pence < 0 ? "-" : (signed && pence > 0 ? "+" : "")
        return "\(sign)£\(body)"
    }

    static func monthLabel(_ month: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM"
        parser.locale = Locale(identifier: "en_GB")
        guard let date = parser.date(from: month) else { return month }
        let output = DateFormatter()
        output.dateFormat = "MMMM yyyy"
        output.locale = Locale(identifier: "en_GB")
        return output.string(from: date)
    }

    static func categoryLabel(_ category: String) -> String {
        category.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

@Observable
@MainActor
final class MoneyPlanViewModel {
    enum LoadState { case idle, loading, loaded, error(String) }

    private(set) var plan: MoneyPlan?
    private(set) var spending: Spending?
    private(set) var loadState: LoadState = .idle

    var isSelecting = false
    var selectedIds: Set<String> = []
    private(set) var preview: BufferPreview?
    private(set) var bufferMessage: String?
    private(set) var bufferError: String?
    private(set) var isMoving = false

    private let apiClient: APIClient
    private let logger = Logger(subsystem: "co.cronx.sparkapp", category: "MoneyPlan")

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    var selectedTotal: Int {
        (spending?.transactions ?? [])
            .filter { selectedIds.contains($0.id) }
            .reduce(0) { $0 + $1.amount }
    }

    func load() async {
        guard case .idle = loadState else { return }
        await fetch()
    }

    func refresh() async {
        await fetch()
    }

    private func fetch() async {
        loadState = .loading
        do {
            async let planResponse = apiClient.request(MoneyEndpoint.plan())
            async let spendingResponse = apiClient.request(MoneyEndpoint.spending())
            let (planResult, spendingResult) = try await (planResponse, spendingResponse)
            plan = planResult.data
            spending = spendingResult.data
            loadState = .loaded
        } catch where error.isAPICancellation {
            loadState = .idle
        } catch {
            SparkObservability.captureHandled(error)
            logger.error("Money plan load failed: \(String(describing: error))")
            loadState = .error((error as? LocalizedError)?.errorDescription ?? "Couldn't load your plan.")
        }
    }

    func toggleSelecting() {
        isSelecting.toggle()
        selectedIds = []
        bufferError = nil
        bufferMessage = nil
    }

    func toggle(_ transaction: SpendingTransaction) {
        guard transaction.canAddToBuffer else { return }
        if selectedIds.contains(transaction.id) {
            selectedIds.remove(transaction.id)
        } else {
            selectedIds.insert(transaction.id)
        }
    }

    /// Asks the server what would move. Moves nothing.
    func reviewBuffer() async {
        bufferError = nil
        bufferMessage = nil
        do {
            preview = try await apiClient.request(MoneyEndpoint.previewBuffer(eventIds: Array(selectedIds))).data
        } catch where error.isAPICancellation {
            return
        } catch {
            bufferError = (error as? LocalizedError)?.errorDescription ?? "Couldn't review that."
        }
    }

    func cancelBuffer() {
        preview = nil
    }

    /// Moves the money the user just confirmed.
    func confirmBuffer() async {
        guard let preview, !isMoving else { return }
        isMoving = true
        defer { isMoving = false }
        do {
            let result = try await apiClient.request(
                MoneyEndpoint.addToBuffer(eventIds: Array(selectedIds), confirmedTotal: preview.total)
            )
            bufferMessage = "Asked Monzo to move \(MoneyPlanFormat.pounds(result.data.total)) into \(preview.pot.name)."
            self.preview = nil
            isSelecting = false
            selectedIds = []
            await fetch()
        } catch where error.isAPICancellation {
            return
        } catch {
            bufferError = (error as? LocalizedError)?.errorDescription ?? "Couldn't move the money."
            self.preview = nil
        }
    }

    func setBufferPot(_ pot: PlanPot, enabled: Bool) async {
        do {
            _ = try await apiClient.request(MoneyEndpoint.setCardBuffer(potId: pot.id, enabled: enabled))
            await fetch()
        } catch where error.isAPICancellation {
            return
        } catch {
            bufferError = (error as? LocalizedError)?.errorDescription ?? "Couldn't change the buffer pot."
        }
    }
}
