import Foundation

/// Person-readable names for the backend's object type keys. Detail screens,
/// rows and search results used to print `concept — type` with underscores
/// swapped for spaces ("user — manual log user"), which repeats the concept
/// inside the type and leaks the schema.
public enum EntityTypeName {
    /// Types whose sentence-cased key reads wrong or says too much.
    private static let overrides: [String: String] = [
        "newsletter_publication": "Newsletter",
        "newsletter_post": "Newsletter post",
        "tv_episode": "TV episode",
        "tv_show": "TV show",
        "user_profile": "Profile",
        "url": "Link",
    ]

    private static let acronyms: [String: String] = [
        "tv": "TV", "url": "URL", "ai": "AI", "gps": "GPS", "hrv": "HRV", "uk": "UK", "id": "ID",
    ]

    /// `tv_episode` -> "TV episode", `newsletter_publication` -> "Newsletter",
    /// `manual_log_user` (concept `user`) -> "Manual log account". Falls back
    /// to the concept when there's no type.
    public static func display(type: String?, concept: String?) -> String {
        let type = (type ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        let concept = (concept ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        let key = type.isEmpty ? concept : type
        guard !key.isEmpty else { return "Object" }

        if let override = overrides[key] { return override }

        // Every integration writes its own account object for the owner
        // (`newsletter_user`, `manual_log_user`). Name it by the integration.
        if isAccountOwner(concept: concept, type: key), key.hasSuffix("_user"), key.count > "_user".count {
            return humanised(String(key.dropLast("_user".count))) + " account"
        }

        return humanised(key)
    }

    /// Whether an object is one of the account owner's own per-integration
    /// user objects. Those sit as the actor on nearly every event, so the
    /// event screen leaves them out. Slack's `slack_user` actors are other
    /// workspace members, so they stay.
    public static func isAccountOwner(concept: String?, type: String?) -> Bool {
        guard concept?.lowercased() == "user" else { return false }
        return !(type?.lowercased().hasPrefix("slack") ?? false)
    }

    private static func humanised(_ key: String) -> String {
        let words = key.sparkSentenceCase.split(separator: " ").map(String.init)
        return words.enumerated().map { index, word in
            if let acronym = acronyms[word.lowercased()] { return acronym }
            return index == 0 ? word : word.lowercased()
        }
        .joined(separator: " ")
    }
}

extension Event.ActorTarget {
    /// The owner's own account object; see `EntityTypeName.isAccountOwner`.
    public var isAccountOwner: Bool { EntityTypeName.isAccountOwner(concept: concept, type: type) }
    public var typeName: String { EntityTypeName.display(type: type, concept: concept) }
}

extension EventDetail.ActorTarget {
    public var isAccountOwner: Bool { EntityTypeName.isAccountOwner(concept: concept, type: type) }
    public var typeName: String { EntityTypeName.display(type: type, concept: concept) }
}

extension EventObject {
    public var isAccountOwner: Bool { EntityTypeName.isAccountOwner(concept: concept, type: type) }
    public var typeName: String { EntityTypeName.display(type: type, concept: concept) }
}
