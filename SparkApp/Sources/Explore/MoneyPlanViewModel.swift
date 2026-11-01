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

    /// Always two decimals, as the design language writes money (`£24.80`).
    static func amount(_ pence: Int, signed: Bool = false) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let body = formatter.string(from: NSNumber(value: Double(abs(pence)) / 100)) ?? "0.00"
        let sign = pence < 0 ? "-" : (signed && pence > 0 ? "+" : "")
        return "\(sign)£\(body)"
    }

    /// A hero value split for display: the pounds at hero size, the pence
    /// smaller beside them. `-£10,470` and `.15`.
    static func heroParts(_ pence: Int) -> (whole: String, fraction: String) {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let pounds = abs(pence) / 100
        let whole = formatter.string(from: NSNumber(value: pounds)) ?? "0"
        let sign = pence < 0 ? "-" : ""
        return ("\(sign)£\(whole)", String(format: ".%02d", abs(pence) % 100))
    }

    /// The day a bill leaves, relative where that reads better:
    /// "Tomorrow, Sunday 1 November", "Thursday 5 November".
    static func dueLabel(_ day: String, now: Date = .now, calendar: Calendar = .current) -> String {
        guard let date = parseDay(day, calendar: calendar) else { return day }
        let output = DateFormatter()
        output.locale = Locale(identifier: "en_GB")
        output.calendar = calendar
        output.timeZone = calendar.timeZone
        output.dateFormat = "EEEE d MMMM"
        let label = output.string(from: date)
        if calendar.isDate(date, inSameDayAs: now) { return "Today, \(label)" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow, \(label)"
        }
        return label
    }

    /// "Payday is Sunday 29 November, in 29 days." `nil` when the server
    /// sent no payday.
    static func paydayLine(_ day: String?, known: Bool, now: Date = .now, calendar: Calendar = .current) -> String? {
        guard let day, let date = parseDay(day, calendar: calendar) else { return nil }
        let output = DateFormatter()
        output.locale = Locale(identifier: "en_GB")
        output.calendar = calendar
        output.timeZone = calendar.timeZone
        output.dateFormat = "EEEE d MMMM"
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: date).day ?? 0
        let lead = known ? "Payday is" : "Counting to"
        switch days {
        case ..<1: return "\(lead) today"
        case 1: return "\(lead) tomorrow"
        default: return "\(lead) \(output.string(from: date)), in \(days) days"
        }
    }

    /// "8 Oct" for 2026-10-08.
    static func shortDay(_ day: String, calendar: Calendar = .current) -> String {
        guard let date = parseDay(day, calendar: calendar) else { return day }
        let output = DateFormatter()
        output.locale = Locale(identifier: "en_GB")
        output.calendar = calendar
        output.timeZone = calendar.timeZone
        output.dateFormat = "d MMM"
        return output.string(from: date)
    }

    static func parseDay(_ day: String, calendar: Calendar = .current) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// The month's first letter, for a chart axis ("S" for 2026-09).
    static func monthInitial(_ month: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM"
        parser.locale = Locale(identifier: "en_GB")
        guard let date = parser.date(from: month) else { return "" }
        let output = DateFormatter()
        output.dateFormat = "MMMMM"
        output.locale = Locale(identifier: "en_GB")
        return output.string(from: date)
    }

    static func monthName(_ month: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM"
        parser.locale = Locale(identifier: "en_GB")
        guard let date = parser.date(from: month) else { return month }
        let output = DateFormatter()
        output.dateFormat = "MMMM"
        output.locale = Locale(identifier: "en_GB")
        return output.string(from: date)
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
            let message = (error as? LocalizedError)?.errorDescription ?? "Couldn't load your plan."
            if plan != nil {
                loadState = .loaded
                bufferError = bufferError ?? message
            } else {
                loadState = .error(message)
            }
        }
    }

    func toggleSelecting() {
        isSelecting.toggle()
        selectedIds = []
        bufferError = nil
        bufferMessage = nil
    }

    func toggle(_ transaction: SpendingTransaction) {
        guard preview == nil, transaction.canAddToBuffer else { return }
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
                MoneyEndpoint.addToBuffer(eventIds: preview.transactions.map(\.id), confirmedTotal: preview.total)
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
