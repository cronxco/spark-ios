import Foundation

/// Response from `GET /widgets/spend`.
public struct SpendWidget: Codable, Sendable {
    public let date: String
    public let total: Double
    public let unit: String
    public let currency: String
    public let transactionCount: Int
    public let topMerchants: [Merchant]

    public struct Merchant: Codable, Sendable, Identifiable {
        public let name: String
        public let total: Double
        public let count: Int
        public var id: String { name }

        public init(name: String, total: Double, count: Int) {
            self.name = name
            self.total = total
            self.count = count
        }
    }

    enum CodingKeys: String, CodingKey {
        case date, total, unit, currency
        case transactionCount = "transaction_count"
        case topMerchants = "top_merchants"
    }

    public init(date: String, total: Double, unit: String, currency: String, transactionCount: Int, topMerchants: [Merchant]) {
        self.date = date
        self.total = total
        self.unit = unit
        self.currency = currency
        self.transactionCount = transactionCount
        self.topMerchants = topMerchants
    }
}
