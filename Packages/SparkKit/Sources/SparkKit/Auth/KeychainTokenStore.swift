import Foundation
import Security

public enum TokenStorageError: Error, Sendable, LocalizedError {
    case keychain(operation: String, status: OSStatus)
    case invalidData

    public var errorDescription: String? {
        switch self {
        case .keychain(_, let status) where status == errSecMissingEntitlement:
            return "Spark cannot access secure sign-in storage. This build is missing its Keychain entitlements. Please install a correctly signed build."
        case .keychain(let operation, let status):
            return "Spark could not \(operation) your secure sign-in details (Keychain error \(status)). Please unlock your device and try again."
        case .invalidData:
            return "Your saved sign-in details could not be read. Please sign in again."
        }
    }
}

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

    public init(
        service: String = "co.cronx.sparkapp.oauth",
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
        try? checkedTokens()
    }

    /// Distinguishes an absent session from inaccessible secure storage.
    public func checkedTokens() throws -> AuthTokens? {
        guard let data = try read() else { return nil }
        guard let decoded = try? JSONDecoder().decode(AuthTokens.self, from: data) else {
            throw TokenStorageError.invalidData
        }
        return decoded
    }

    // MARK: - Write

    public func store(access: String, refresh: String, expiresIn: Int) throws {
        let tokens = AuthTokens(
            accessToken: access,
            refreshToken: refresh,
            issuedAt: Date(),
            expiresIn: expiresIn
        )
        let data = try JSONEncoder().encode(tokens)
        try write(data)
        // Do not report a successful sign-in until storage is readable too.
        guard try checkedTokens() == tokens else { throw TokenStorageError.invalidData }
    }

    public func clear() {
        delete()
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

    private func read() throws -> Data? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw TokenStorageError.keychain(operation: "read", status: status)
        }
        guard let data = item as? Data else { throw TokenStorageError.invalidData }
        return data
    }

    private func write(_ data: Data) throws {
        let query = baseQuery()
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery.merge(attributes) { _, new in new }
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            throw TokenStorageError.keychain(operation: "save", status: status)
        }
    }

    private func delete() {
        SecItemDelete(baseQuery() as CFDictionary)
    }
}
