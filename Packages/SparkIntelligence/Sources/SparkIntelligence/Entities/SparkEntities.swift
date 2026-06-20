import AppIntents
import CoreSpotlight
import Foundation
import SparkKit

// MARK: - Spark App Entities (iOS 27 semantic index + Siri context)
//
// Each domain model is surfaced to the new Siri as an `AppEntity` that also
// conforms to `IndexedEntity`, feeding Spark's personal data into the on-device
// Spotlight semantic index. Searchable fields are tagged with
// `@Property(indexingKey:)` so the index keeps Spark-attributed content the new
// Siri can reason over ("what did I do today", "how's my sleep trending").
//
// App Schemas (`@AssistantEntity(schema:)`) are adopted per-entity at build time
// where the shipped iOS 27 SDK provides a clean fit; everything here is the
// sanctioned custom-entity fallback, which always satisfies the schema
// completeness check. Mapping initializers read the cached SwiftData rows so the
// extension process can build entities without a network round-trip.

// MARK: Event

public struct EventEntity: AppEntity, IndexedEntity {
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Event",
        numericFormat: "\(placeholder: .int) events"
    )
    public static let defaultQuery = EventEntityQuery()

    public let id: String

    @Property(indexingKey: \.title)
    public var title: String

    @Property(indexingKey: \.contentDescription)
    public var summary: String?

    @Property(indexingKey: \.keywords)
    public var tags: [String]

    public var service: String
    public var domain: String
    public var action: String
    public var timestamp: Date?

    public init(
        id: String,
        title: String,
        summary: String?,
        tags: [String],
        service: String,
        domain: String,
        action: String,
        timestamp: Date?
    ) {
        self.id = id
        self.service = service
        self.domain = domain
        self.action = action
        self.timestamp = timestamp
        self.title = title
        self.summary = summary
        self.tags = tags
    }

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: summary.map { "\($0)" } ?? "\(service.capitalized)"
        )
    }
}

public extension EventEntity {
    init(cached event: CachedEvent) {
        let actionLabel = event.action.replacingOccurrences(of: "_", with: " ").capitalized
        let domainLabel = event.domain.replacingOccurrences(of: "_", with: " ").capitalized
        let title = event.displayName?.nonEmpty ?? "\(actionLabel) \(domainLabel)"
        self.init(
            id: event.id,
            title: title,
            summary: event.displayValue?.nonEmpty ?? event.service.capitalized,
            tags: [event.service, event.domain, event.action].filter { !$0.isEmpty },
            service: event.service,
            domain: event.domain,
            action: event.action,
            timestamp: event.time
        )
    }
}

// MARK: Block

public struct BlockEntity: AppEntity, IndexedEntity {
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Block")
    public static let defaultQuery = BlockEntityQuery()

    public let id: String

    @Property(indexingKey: \.title)
    public var title: String

    @Property(indexingKey: \.contentDescription)
    public var body: String?

    @Property(indexingKey: \.keywords)
    public var keywords: [String]

    public var blockType: String
    public var timestamp: Date?

    public init(id: String, title: String, body: String?, blockType: String, timestamp: Date?) {
        self.id = id
        self.blockType = blockType
        self.timestamp = timestamp
        self.title = title
        self.body = body
        self.keywords = [blockType].filter { !$0.isEmpty }
    }

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: body.map { "\($0)" })
    }
}

public extension BlockEntity {
    init(cached block: CachedBlock) {
        self.init(
            id: block.id,
            title: block.title,
            body: block.content?.nonEmpty,
            blockType: block.blockType,
            timestamp: block.time
        )
    }
}

// MARK: Place

public struct PlaceEntity: AppEntity, IndexedEntity {
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Place")
    public static let defaultQuery = PlaceEntityQuery()

    public let id: String

    @Property(indexingKey: \.title)
    public var name: String

    @Property(indexingKey: \.contentDescription)
    public var address: String?

    public var category: String?
    public var latitude: Double?
    public var longitude: Double?
    public var visitCount: Int?

    public init(
        id: String,
        name: String,
        address: String?,
        category: String?,
        latitude: Double?,
        longitude: Double?,
        visitCount: Int?
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.category = category
        self.latitude = latitude
        self.longitude = longitude
        self.visitCount = visitCount
    }

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: address.map { "\($0)" })
    }

    // Geo coordinates aren't expressible as `@Property(indexingKey:)` (NSNumber
    // bridging), so enrich the synthesized attribute set directly.
    public func updateAttributeSet(_ attributeSet: inout CSSearchableItemAttributeSet) {
        if let latitude { attributeSet.latitude = NSNumber(value: latitude) }
        if let longitude { attributeSet.longitude = NSNumber(value: longitude) }
        attributeSet.namedLocation = name
    }
}

public extension PlaceEntity {
    init(cached place: CachedPlace) {
        self.init(
            id: place.id,
            name: place.title,
            address: place.address?.nonEmpty,
            category: place.category?.nonEmpty ?? place.type?.nonEmpty,
            latitude: place.latitude,
            longitude: place.longitude,
            visitCount: nil
        )
    }
}

// MARK: Metric

public struct MetricEntity: AppEntity, IndexedEntity {
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Metric")
    public static let defaultQuery = MetricEntityQuery()

    /// Stable metric identifier (`service.action`) — matches DeepLink routing.
    public let id: String

    @Property(indexingKey: \.title)
    public var displayName: String

    @Property(indexingKey: \.contentDescription)
    public var latestValueDescription: String?

    @Property(indexingKey: \.keywords)
    public var keywords: [String]

    public var unit: String?
    public var latestValue: Double?
    public var lastEventAt: Date?

    public init(
        id: String,
        displayName: String,
        latestValue: Double?,
        unit: String?,
        lastEventAt: Date?,
        keywords: [String]
    ) {
        self.id = id
        self.displayName = displayName
        self.latestValue = latestValue
        self.unit = unit
        self.lastEventAt = lastEventAt
        self.keywords = keywords
        if let latestValue {
            let formatted = Self.numberFormatter.string(from: NSNumber(value: latestValue)) ?? "\(latestValue)"
            self.latestValueDescription = unit.map { "\(formatted) \($0)" } ?? formatted
        } else {
            self.latestValueDescription = nil
        }
    }

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(displayName)",
            subtitle: latestValueDescription.map { "\($0)" }
        )
    }

    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        return f
    }()
}

public extension MetricEntity {
    init(cached metric: CachedMetric) {
        self.init(
            id: metric.identifier,
            displayName: metric.displayName,
            latestValue: metric.mean,
            unit: metric.unit?.nonEmpty,
            lastEventAt: metric.lastEventAt,
            keywords: [metric.service, metric.action].filter { !$0.isEmpty }
        )
    }
}

// MARK: Anomaly

public struct AnomalyEntity: AppEntity, IndexedEntity {
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Anomaly")
    public static let defaultQuery = AnomalyEntityQuery()

    public let id: String

    @Property(indexingKey: \.title)
    public var summary: String

    @Property(indexingKey: \.keywords)
    public var keywords: [String]

    public var metric: String?
    public var direction: String?
    public var detectedAt: Date?
    public var acknowledged: Bool

    public init(
        id: String,
        summary: String,
        metric: String?,
        direction: String?,
        detectedAt: Date?,
        acknowledged: Bool
    ) {
        self.id = id
        self.metric = metric
        self.direction = direction
        self.detectedAt = detectedAt
        self.acknowledged = acknowledged
        self.summary = summary
        self.keywords = [metric, direction, "anomaly"].compactMap { $0?.nonEmpty }
    }

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(summary)",
            subtitle: acknowledged ? "Acknowledged" : "Needs review"
        )
    }
}

public extension AnomalyEntity {
    init(cached anomaly: CachedAnomaly) {
        let summary = anomaly.desc?.nonEmpty
            ?? anomaly.metric.map { "Unusual reading for \($0)" }
            ?? "Anomaly detected"
        self.init(
            id: anomaly.id,
            summary: summary,
            metric: anomaly.metric,
            direction: nil,
            detectedAt: anomaly.detectedAt,
            acknowledged: anomaly.acknowledgedAt != nil
        )
    }
}

// MARK: Integration

public struct IntegrationEntity: AppEntity, IndexedEntity {
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Integration")
    public static let defaultQuery = IntegrationEntityQuery()

    /// Service slug — matches `DeepLink.integration(service:)` routing.
    public let id: String

    @Property(indexingKey: \.title)
    public var name: String

    @Property(indexingKey: \.contentDescription)
    public var statusDescription: String?

    public var service: String
    public var status: String

    public init(id: String, name: String, service: String, status: String) {
        self.id = id
        self.service = service
        self.status = status
        self.name = name
        self.statusDescription = "Status: \(status.capitalized)"
    }

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(status.capitalized)")
    }
}

public extension IntegrationEntity {
    init(cached integration: CachedIntegration) {
        self.init(
            id: integration.service,
            name: integration.name,
            service: integration.service,
            status: integration.status
        )
    }
}

// MARK: Money Account

public struct MoneyAccountEntity: AppEntity, IndexedEntity {
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Money Account")
    public static let defaultQuery = MoneyAccountEntityQuery()

    public let id: String

    @Property(indexingKey: \.title)
    public var title: String

    @Property(indexingKey: \.contentDescription)
    public var balanceDescription: String?

    @Property(indexingKey: \.keywords)
    public var keywords: [String]

    public var kind: String
    public var accountType: String?
    public var currency: String
    public var provider: String?
    public var latestBalance: Double?
    public var updatedAt: Date?

    public init(
        id: String,
        title: String,
        kind: String,
        accountType: String?,
        currency: String,
        provider: String?,
        latestBalance: Double?,
        updatedAt: Date?
    ) {
        self.id = id
        self.kind = kind
        self.accountType = accountType
        self.currency = currency
        self.provider = provider
        self.latestBalance = latestBalance
        self.updatedAt = updatedAt
        self.title = title
        self.keywords = [kind, accountType, currency, provider].compactMap { $0?.nonEmpty }
        if let latestBalance {
            self.balanceDescription = Self.currencyFormatter(currency: currency)
                .string(from: NSNumber(value: latestBalance))
        } else {
            self.balanceDescription = nil
        }
    }

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: balanceDescription.map { "\($0)" } ?? accountType.map { "\($0.capitalized)" }
        )
    }

    static func currencyFormatter(currency: String) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 2
        return formatter
    }
}

public extension MoneyAccountEntity {
    init(cached account: CachedMoneyAccount) {
        self.init(
            id: account.id,
            title: account.title,
            kind: account.kind,
            accountType: account.accountType,
            currency: account.currency,
            provider: account.provider,
            latestBalance: account.latestBalance,
            updatedAt: account.updatedAt
        )
    }
}

// MARK: Spend Summary

public struct SpendSummaryEntity: AppEntity, IndexedEntity {
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Spend Summary")
    public static let defaultQuery = SpendSummaryEntityQuery()

    /// Stable identifier scoped away from `DaySummaryEntity` (`spend:yyyy-MM-dd`).
    public let id: String

    @Property(indexingKey: \.title)
    public var title: String

    @Property(indexingKey: \.contentDescription)
    public var summary: String?

    @Property(indexingKey: \.keywords)
    public var keywords: [String]

    public var date: Date?
    public var total: Double?
    public var currency: String
    public var transactionCount: Int?
    public var topMerchants: [String]

    public init(
        dateKey: String,
        date: Date?,
        total: Double?,
        currency: String,
        transactionCount: Int?,
        topMerchants: [String]
    ) {
        self.id = "spend:\(dateKey)"
        self.date = date
        self.total = total
        self.currency = currency
        self.transactionCount = transactionCount
        self.topMerchants = topMerchants
        self.title = "Spend on \(dateKey)"
        self.keywords = ["money", "spend", "transactions"] + topMerchants

        var parts: [String] = []
        if let total {
            let formatted = MoneyAccountEntity.currencyFormatter(currency: currency)
                .string(from: NSNumber(value: abs(total))) ?? "\(abs(total)) \(currency)"
            parts.append("Spent \(formatted)")
        }
        if let transactionCount {
            parts.append("\(transactionCount) transaction\(transactionCount == 1 ? "" : "s")")
        }
        if !topMerchants.isEmpty {
            parts.append("Top merchants: \(topMerchants.prefix(3).joined(separator: ", "))")
        }
        self.summary = parts.isEmpty ? nil : parts.joined(separator: "; ")
    }

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: summary.map { "\($0)" })
    }
}

public extension SpendSummaryEntity {
    init?(cached summary: CachedDaySummary) {
        guard let decoded = try? summary.decoded(),
              let money = decoded.sections.money?.objectValue
        else { return nil }

        let total = money["total_spend"]?.doubleValue
            ?? money["total"]?.doubleValue
            ?? money["amount"]?.doubleValue
        let transactions = money["transactions"]?.arrayValue ?? []
        let currency = money["currency"]?.stringValue
            ?? transactions.first?.objectValue?["currency"]?.stringValue
            ?? "GBP"
        let topMerchants = (money["top_merchants"]?.arrayValue ?? [])
            .compactMap { item -> String? in
                if let name = item.objectValue?["name"]?.stringValue { return name }
                return item.stringValue
            }

        self.init(
            dateKey: decoded.date,
            date: DaySummaryEntity.isoFormatter.date(from: decoded.date),
            total: total,
            currency: currency,
            transactionCount: transactions.isEmpty ? nil : transactions.count,
            topMerchants: topMerchants
        )
    }
}

// MARK: DaySummary

public struct DaySummaryEntity: AppEntity, IndexedEntity {
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Day")
    public static let defaultQuery = DaySummaryEntityQuery()

    /// ISO date string `yyyy-MM-dd` — the "what happened today" anchor.
    public let id: String

    @Property(indexingKey: \.title)
    public var title: String

    @Property(indexingKey: \.contentDescription)
    public var highlights: String?

    public var date: Date?

    public init(id: String, title: String, highlights: String?, date: Date?) {
        self.id = id
        self.title = title
        self.highlights = highlights
        self.date = date
    }

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: highlights.map { "\($0)" })
    }
}

public extension DaySummaryEntity {
    init(cached summary: CachedDaySummary) {
        let date = DaySummaryEntity.isoFormatter.date(from: summary.date)
        let title: String
        if let date {
            title = DaySummaryEntity.titleFormatter.string(from: date)
        } else {
            title = summary.date
        }
        var highlightParts: [String] = []
        if let decoded = try? summary.decoded() {
            if !decoded.anomalies.isEmpty {
                highlightParts.append("\(decoded.anomalies.count) anomaly\(decoded.anomalies.count == 1 ? "" : "ies")")
            }
            let snapshot = TodayIntentSnapshot(summary: decoded)
            if let steps = snapshot.steps { highlightParts.append("\(steps) steps") }
            if let score = snapshot.sleepScore { highlightParts.append("sleep \(score)") }
        }
        self.init(
            id: summary.date,
            title: title,
            highlights: highlightParts.isEmpty ? nil : highlightParts.joined(separator: " · "),
            date: date
        )
    }

    static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()

    private static let titleFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .full
        return f
    }()
}

// MARK: - Helpers

extension String {
    /// Returns `nil` for empty/whitespace strings, the trimmed value otherwise.
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
