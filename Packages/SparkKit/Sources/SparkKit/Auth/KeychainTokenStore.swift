import Foundation
import Security

public struct AuthTokens: Sendable, Hashable, Codable {
    public let accessToken: String
    public let refreshToken: String
    public let issuedAt: Date
    public let expiresIn: Int

    public var expiresAt: Date { issuedAt.addingTimeInterval(TimeInterval(expiresIn)) }

    public init(accessToken: String, refreshToken: String, issuedAt: Date = .init(), expiresIn: Int) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.issuedAt = issuedAt
        self.expiresIn = expiresIn
    }
}

/// Stores the Sanctum OAuth tokens in a Keychain item shared across the app
/// group so widgets and extensions can authenticate against the mobile API
/// without a second login.
///
/// Values are persisted under a single Keychain item as a JSON blob, tagged
/// with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
public actor KeychainTokenStore {
    private let service: String
    private let account: String
    private let accessGroup: String?
    private var cachedTokens: AuthTokens?

    public init(
        service: String = "co.cronx.spark.oauth",
        account: String = "primary",
        accessGroup: String? = nil
    ) {
        self.service = service
        self.account = account
        self.accessGroup = accessGroup
    }

    // MARK: - Read

    public func accessToken() -> String? { tokens()?.accessToken }
    public func refreshToken() -> String? { tokens()?.refreshToken }
    public func hasRefreshToken() -> Bool { tokens()?.refreshToken.isEmpty == false }

    public func tokens() -> AuthTokens? {
        if let cachedTokens { return cachedTokens }
        guard let data = read() else { return nil }
        let decoded = try? JSONDecoder().decode(AuthTokens.self, from: data)
        cachedTokens = decoded
        return decoded
    }

    // MARK: - Write

    public func store(access: String, refresh: String, expiresIn: Int) {
        let tokens = AuthTokens(
            accessToken: access,
            refreshToken: refresh,
            issuedAt: Date(),
            expiresIn: expiresIn
        )
        guard let data = try? JSONEncoder().encode(tokens) else { return }
        write(data)
        cachedTokens = tokens
    }

    public func clear() {
        delete()
        cachedTokens = nil
    }

    // MARK: - Keychain plumbing

    private func baseQuery() -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }

    private func read() -> Data? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    private func write(_ data: Data) {
        let query = baseQuery()
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery.merge(attributes) { _, new in new }
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    private func delete() {
        SecItemDelete(baseQuery() as CFDictionary)
    }
}
