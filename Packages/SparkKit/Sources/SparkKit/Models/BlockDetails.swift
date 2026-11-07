import Foundation

/// The typed fields a block's card reads, from `details` on `CompactBlockResource`.
///
/// The backend sends only an allowlist per block type, already checked for
/// type, so raw metadata never reaches the app. Money is in major units
/// beside `currency`. A field the source didn't have is simply absent.
public struct BlockDetails: Codable, Sendable, Hashable {
    public let fields: [String: AnyCodable]

    public init(_ fields: [String: AnyCodable]) {
        self.fields = fields
    }

    public init(from decoder: Decoder) throws {
        fields = try decoder.singleValueContainer().decode([String: AnyCodable].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(fields)
    }

    public func string(_ key: String) -> String? {
        guard let text = fields[key]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }

    public func number(_ key: String) -> Double? {
        fields[key]?.doubleValue
    }

    public func int(_ key: String) -> Int? {
        fields[key]?.intValue
    }

    public func strings(_ key: String) -> [String] {
        fields[key]?.arrayValue?.compactMap(\.stringValue) ?? []
    }

    public var currency: String? { string("currency") }
}

/// One labelled reading on a block's card, such as "Reps 8" or "ABV 5.2%".
public struct BlockFact: Sendable, Hashable, Identifiable {
    public let label: String
    public let value: String

    public var id: String { label }

    public init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }
}

public extension Block {
    /// The block's details as labelled readings for its stat grid (§8),
    /// in the order the web card shows them. Empty for kinds without a
    /// custom card, and for blocks the backend sent no details for.
    var facts: [BlockFact] {
        guard let details else { return [] }
        let d = details
        var items = [BlockFact?]()

        switch kind {
        case .track:
            items = [
                d.string("album").map { BlockFact("Album", $0) },
                Self.joined(d.strings("artists")).map { BlockFact("Artists", $0) },
                d.int("duration_ms").map { BlockFact("Length", Self.minutesAndSeconds(milliseconds: $0)) },
                d.number("popularity").map { BlockFact("Popularity", Self.plain($0)) },
            ]
        case .albumArt:
            items = [
                d.string("artist").map { BlockFact("Artist", $0) },
                d.string("track").map { BlockFact("Track", $0) },
            ]
        case .artist:
            items = [
                d.int("followers").map { BlockFact("Followers", $0.formatted()) },
                Self.joined(d.strings("genres")).map { BlockFact("Genres", $0) },
            ]
        case .exercise:
            let unit = d.string("unit") ?? "kg"
            items = [
                d.int("set_number").map { BlockFact("Set", String($0)) },
                d.int("reps").map { BlockFact("Reps", String($0)) },
                d.number("weight").map { BlockFact("Weight", "\(Self.plain($0)) \(unit)") },
                d.number("rpe").map { BlockFact("RPE", Self.plain($0)) },
            ]
        case .exerciseSummary:
            let unit = d.string("unit") ?? "kg"
            items = [
                d.int("sets_count").map { BlockFact("Sets", String($0)) },
                d.number("total_volume").map { BlockFact("Volume", "\(Self.plain($0)) \(unit)") },
            ]
        case .balanceChange:
            items = [d.string("direction").map { BlockFact("Direction", $0.capitalized) }]
        case .bankTransfer:
            items = [d.string("counterparty").map { BlockFact("To", $0) }]
        case .potTransfer:
            items = [
                d.string("pot_name").map { BlockFact("Pot", $0) },
                d.string("direction").map { BlockFact("Direction", $0.capitalized) },
            ]
        case .foreignExchange:
            items = [d.number("rate").map { BlockFact("Rate", Self.plain($0, maximumFractionDigits: 4)) }]
        case .merchant:
            items = [
                d.string("category").map { BlockFact("Category", Self.words($0)) },
                d.string("address").map { BlockFact("Address", $0) },
            ]
        case .receiptLineItem:
            items = [
                d.number("quantity").map { quantity in BlockFact("Quantity", [Self.plain(quantity), d.string("unit")].compactMap { $0 }.joined(separator: " ")) },
                d.number("unit_price").map { BlockFact("Each", Self.money($0, currency: d.currency)) },
                d.string("category").map { BlockFact("Category", Self.words($0)) },
            ]
        case .receiptTaxSummary:
            items = [
                d.number("subtotal").map { BlockFact("Subtotal", Self.money($0, currency: d.currency)) },
                d.number("tax_rate").map { BlockFact("Tax", "\(Self.plain($0))%") },
                d.number("discount_total").map { BlockFact("Discount", Self.money($0, currency: d.currency)) },
                d.number("tip_amount").map { BlockFact("Tip", Self.money($0, currency: d.currency)) },
            ]
        case .receiptPaymentMethod:
            items = [
                d.string("payment_method").map { BlockFact("Paid by", Self.words($0)) },
                d.string("card_last_4").map { BlockFact("Card", "•••• \($0)") },
            ]
        case .book:
            let series = d.string("series_name").map { name in
                d.number("series_number").map { "\(name) #\(Self.plain($0))" } ?? name
            }
            items = [
                d.string("author").map { BlockFact("Author", $0) },
                series.map { BlockFact("Series", $0) },
                d.int("num_pages").map { BlockFact("Pages", $0.formatted()) },
                d.int("published_year").map { BlockFact("Published", String($0)) },
                d.number("average_rating").map { BlockFact("Rating", Self.plain($0, maximumFractionDigits: 2)) },
                d.number("user_rating").map { BlockFact("Your rating", Self.plain($0)) },
                d.number("current_progress").map { BlockFact("Progress", "\(Self.plain($0))%") },
            ]
        case .beer:
            items = [
                d.string("style").map { BlockFact("Style", $0) },
                d.number("abv").map { BlockFact("ABV", "\(Self.plain($0))%") },
                d.number("ibu").map { BlockFact("IBU", Self.plain($0)) },
                d.number("aggregate_rating").map { BlockFact("Rating", Self.plain($0, maximumFractionDigits: 2)) },
                d.int("review_count").map { BlockFact("Reviews", $0.formatted()) },
            ]
        case .brewery:
            let place = [d.string("locality"), d.string("region")].compactMap { $0 }
            items = [
                d.string("venue").map { BlockFact("Venue", $0) },
                place.isEmpty ? nil : BlockFact("From", place.joined(separator: ", ")),
                d.number("aggregate_rating").map { BlockFact("Rating", Self.plain($0, maximumFractionDigits: 2)) },
                d.int("review_count").map { BlockFact("Reviews", $0.formatted()) },
            ]
        default:
            items = []
        }

        return items.compactMap { $0 }
    }

    /// Whether the block is drawn as a record: a card with a stat grid.
    var isRecord: Bool {
        switch kind {
        case .exercise, .receiptLineItem:
            // Many to an event; these stay tiles and rows.
            false
        default:
            !facts.isEmpty
        }
    }

    private static func joined(_ items: [String]) -> String? {
        items.isEmpty ? nil : items.joined(separator: ", ")
    }

    private static func plain(_ number: Double, maximumFractionDigits: Int = 1) -> String {
        number.formatted(.number.precision(.fractionLength(0 ... maximumFractionDigits)))
    }

    private static func money(_ amount: Double, currency: String?) -> String {
        guard let currency else { return amount.formatted(.number.precision(.fractionLength(2))) }
        return amount.formatted(.currency(code: currency))
    }

    private static func minutesAndSeconds(milliseconds: Int) -> String {
        let seconds = max(0, milliseconds / 1000)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    /// "eating_out" reads as "Eating out".
    private static func words(_ raw: String) -> String {
        let spaced = raw.replacingOccurrences(of: "_", with: " ")
        return spaced.prefix(1).uppercased() + spaced.dropFirst()
    }
}
