import Foundation

/// The groups Explore's Tags section sorts tag types into. A family is a few
/// related types, so the screen shows a handful of sections instead of one
/// per raw type (about 18 of them).
public enum TagFamily: String, CaseIterable, Sendable, Hashable, Codable {
    /// Tags you added yourself, and tags with no type.
    case yours
    case people
    /// Spotify artists, albums, contexts and podcasts.
    case music
    /// What a payment was for and where: category, merchant emoji, country.
    case spending
    /// Type, scheme, status, currency and the like. Nearly every card
    /// payment carries one of each, so they would crowd anything ranked by use.
    case paymentDetails
    case other

    /// The order the families appear in, top to bottom.
    public static let displayOrder: [TagFamily] = [.yours, .people, .music, .spending, .other, .paymentDetails]

    public init(tagType: String?) {
        let type = TagTypeName.normalized(tagType)
        if let family = Self.exact[type] {
            self = family
        } else if type.hasPrefix("music_") || type.hasPrefix("spotify_") || type.hasPrefix("podcast_") {
            self = .music
        } else if type.hasPrefix("transaction_") {
            self = .paymentDetails
        } else if type.hasPrefix("merchant_") {
            self = .spending
        } else {
            self = .other
        }
    }

    private static let exact: [String: TagFamily] = [
        TagTypeName.untyped: .yours,
        "spark": .yours,
        "person": .people,
        "transaction_category": .spending,
        "merchant_emoji": .spending,
        "merchant_country": .spending,
        "merchant_category": .spending,
        "decline_reason": .spending,
        "transaction_type": .paymentDetails,
        "transaction_scheme": .paymentDetails,
        "transaction_status": .paymentDetails,
        "transaction_currency": .paymentDetails,
        "balance_type": .paymentDetails,
        "card_pan": .paymentDetails,
    ]

    public var title: String {
        switch self {
        case .yours: "Your tags"
        case .people: "People"
        case .music: "Music and podcasts"
        case .spending: "Spending"
        case .paymentDetails: "Payment details"
        case .other: "Other tags"
        }
    }

    /// One line under a collapsed family's title saying what is inside.
    public var summary: String? {
        switch self {
        case .paymentDetails: "Type, scheme, status and currency"
        default: nil
        }
    }

    /// Payment details start collapsed: they are on every card payment.
    public var startsCollapsed: Bool { self == .paymentDetails }

    /// Whether this family's tags can appear in Most used.
    public var ranksInMostUsed: Bool { self != .paymentDetails }

    /// The order a family's types fall back to when there are no usage
    /// totals to rank them by.
    static let typeOrder: [String] = [
        "spark", TagTypeName.untyped, "person",
        "music_artist", "music_album", "spotify_context", "podcast_show", "podcast_publisher",
        "transaction_category", "merchant_emoji", "merchant_country", "merchant_category", "decline_reason",
        "transaction_type", "transaction_scheme", "transaction_status", "transaction_currency", "balance_type", "card_pan",
    ]
}

/// Display names for tag types, in sentence case.
public enum TagTypeName {
    /// The type the API lists and filters tags without one under.
    public static let untyped = "untyped"

    static func normalized(_ type: String?) -> String {
        let trimmed = (type ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty ? untyped : trimmed
    }

    /// A heading over a set of tags of one type: "Artists", "Countries".
    public static func plural(_ type: String?) -> String {
        let type = normalized(type)
        if let name = plurals[type] { return name }
        return humanized(type)
    }

    /// One tag's type, for a list row or a peek card: "Music artist".
    public static func singular(_ type: String?) -> String {
        let type = normalized(type)
        if let name = singulars[type] { return name }
        return humanized(type)
    }

    private static let plurals: [String: String] = [
        untyped: "Without a type",
        "spark": "Added by you",
        "person": "People",
        "music_artist": "Artists",
        "music_album": "Albums",
        "spotify_context": "Listened from",
        "podcast_show": "Podcasts",
        "podcast_publisher": "Podcast publishers",
        "transaction_category": "Categories",
        "merchant_emoji": "Merchant emoji",
        "merchant_country": "Countries",
        "merchant_category": "Merchant categories",
        "decline_reason": "Decline reasons",
        "transaction_type": "Types",
        "transaction_scheme": "Schemes",
        "transaction_status": "Statuses",
        "transaction_currency": "Currencies",
        "balance_type": "Balance types",
        "card_pan": "Cards",
        "emoji": "Emoji",
    ]

    private static let singulars: [String: String] = [
        untyped: "Tag",
        "spark": "Your tag",
        "spotify_context": "Spotify context",
        "podcast_show": "Podcast",
        "card_pan": "Card",
    ]

    /// `merchant_country` → "Merchant country".
    static func humanized(_ type: String) -> String {
        let words = type
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map { $0.lowercased() }
        guard let first = words.first else { return "Tag" }
        return ([first.prefix(1).uppercased() + first.dropFirst()] + words.dropFirst()).joined(separator: " ")
    }
}

/// One type's tags inside a family, as Explore's Tags section shows them.
public struct TagTypeGroup: Sendable, Hashable, Identifiable {
    public let type: String
    /// The type's most used tags that have loaded so far.
    public let tags: [TagResource]
    /// How many tags of this type there are in all.
    public let tagsCount: Int
    public let totalCount: Int

    public var id: String { type }
    public var title: String { TagTypeName.plural(type) }
    /// Tags of this type that are not shown.
    public var hiddenCount: Int { max(0, tagsCount - tags.count) }
}

/// A family with its groups, in the order the screen shows them.
public struct TagFamilySection: Sendable, Hashable, Identifiable {
    public let family: TagFamily
    public let groups: [TagTypeGroup]

    public var id: TagFamily { family }
    public var tagsCount: Int { groups.reduce(0) { $0 + $1.tagsCount } }
}

public enum TagCatalogue {
    /// Sorts tags into families and their types. `totals` (from the first
    /// page) gives each type its true size and its rank; without it the
    /// sizes are counted from `tags`, which is only what has loaded.
    /// - Parameter perGroup: how many tags each type shows.
    public static func sections(
        tags: [TagResource],
        totals: [TagTypeTotal]?,
        perGroup: Int = 8
    ) -> [TagFamilySection] {
        let byType = Dictionary(grouping: tags) { TagTypeName.normalized($0.type) }
        let totals = totals ?? byType.map { type, tags in
            TagTypeTotal(type: type, tagsCount: tags.count, totalCount: tags.reduce(0) { $0 + $1.totalCount })
        }

        let groups = totals
            .filter { $0.tagsCount > 0 }
            .map { total -> TagTypeGroup in
                let type = TagTypeName.normalized(total.type)
                let loaded = (byType[type] ?? []).sorted(by: usage)
                return TagTypeGroup(
                    type: type,
                    tags: Array(loaded.prefix(perGroup)),
                    tagsCount: total.tagsCount,
                    totalCount: total.totalCount
                )
            }

        let byFamily = Dictionary(grouping: groups) { TagFamily(tagType: $0.type) }
        return TagFamily.displayOrder.compactMap { family in
            guard let groups = byFamily[family], !groups.isEmpty else { return nil }
            return TagFamilySection(family: family, groups: groups.sorted(by: groupOrder))
        }
    }

    /// The most used tags, leaving out families that would crowd the list.
    public static func mostUsed(_ tags: [TagResource], limit: Int = 5) -> [TagResource] {
        Array(
            tags
                .filter { TagFamily(tagType: $0.type).ranksInMostUsed && $0.totalCount > 0 }
                .sorted(by: usage)
                .prefix(limit)
        )
    }

    private static func usage(_ lhs: TagResource, _ rhs: TagResource) -> Bool {
        if lhs.totalCount != rhs.totalCount { return lhs.totalCount > rhs.totalCount }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    private static func groupOrder(_ lhs: TagTypeGroup, _ rhs: TagTypeGroup) -> Bool {
        if lhs.totalCount != rhs.totalCount { return lhs.totalCount > rhs.totalCount }
        let order = TagFamily.typeOrder
        let left = order.firstIndex(of: lhs.type) ?? order.count
        let right = order.firstIndex(of: rhs.type) ?? order.count
        if left != right { return left < right }
        return lhs.type < rhs.type
    }
}
