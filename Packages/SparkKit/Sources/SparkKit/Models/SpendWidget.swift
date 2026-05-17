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
        public let count: Int?
        public var id: String { name }

        public init(name: String, total: Double, count: Int? = nil) {
            self.name = name
            self.total = total
            self.count = count
        }

        enum CodingKeys: String, CodingKey {
            case name, total, amount, count
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            total = try container.decodeIfPresent(Double.self, forKey: .total)
                ?? container.decode(Double.self, forKey: .amount)
            count = try container.decodeIfPresent(Int.self, forKey: .count)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
            try container.encode(total, forKey: .total)
            try container.encodeIfPresent(count, forKey: .count)
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
