import Foundation

/// Per-URL ETag store backed by App Group `UserDefaults`. Shared with widgets
/// and extensions so they don't redownload what the main app already has.
public actor ETagCache {
    private let defaults: UserDefaults
    private let keyPrefix = "spark.etag."

    public init(defaults: UserDefaults = .sparkAppGroup) {
        self.defaults = defaults
    }

    public func etag(for url: URL) -> String? {
        defaults.string(forKey: key(for: url))
    }

    public func store(_ etag: String, for url: URL) {
        defaults.set(etag, forKey: key(for: url))
    }

    public func clear(for url: URL) {
        defaults.removeObject(forKey: key(for: url))
    }

    public func clearAll() {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(keyPrefix) {
            defaults.removeObject(forKey: key)
        }
    }

    private func key(for url: URL) -> String {
        keyPrefix + url.absoluteString
    }
}
