import Foundation
import Testing
@testable import SparkKit

/// NOTIF-03 — the notification taxonomy.
///
/// The mobile API invented five categories (anomaly, digest, integration_failed,
/// new_bookmark, calendar_event) of which only `integration_failed` named a
/// notification that is ever sent. `SparkNotification::via()` gates delivery on
/// the real type string, so four of the five toggles controlled nothing, and
/// three types that are sent had no toggle at all.
///
/// These raw values are a wire contract with `NotificationCatalogue` on the
/// backend. Decoding drops unrecognised keys, so a case missing here silently
/// removes that toggle from Settings rather than failing loudly.
@Suite("Notification categories")
struct NotificationCategoryTests {
    /// Mirrors `NotificationCatalogue::configurableTypes()`.
    private let backendTypes: Set<String> = [
        "integration_completed",
        "integration_failed",
        "integration_authentication_failed",
        "cookie_expiry_warning",
        "fetch_multiple_failures",
        "fetch_content_changed",
        "migration_completed",
        "migration_failed",
        "data_export_ready",
        "system_maintenance",
    ]

    @Test("every category matches a backend notification type")
    func categoriesMatchBackend() {
        let clientTypes = Set(NotificationPreferences.Category.allCases.map(\.rawValue))

        #expect(clientTypes == backendTypes)
    }

    @Test("the withdrawn categories are gone")
    func withdrawnCategoriesAreGone() {
        let clientTypes = Set(NotificationPreferences.Category.allCases.map(\.rawValue))

        for withdrawn in ["anomaly", "digest", "new_bookmark", "calendar_event"] {
            #expect(!clientTypes.contains(withdrawn))
        }
    }

    @Test("every category has distinct, non-empty copy")
    func everyCategoryHasCopy() {
        let names = NotificationPreferences.Category.allCases.map(\.displayName)
        let subtitles = NotificationPreferences.Category.allCases.map(\.subtitle)
        let namesAreNonEmpty = names.allSatisfy { !$0.isEmpty }
        let subtitlesAreNonEmpty = subtitles.allSatisfy { !$0.isEmpty }

        #expect(namesAreNonEmpty)
        #expect(subtitlesAreNonEmpty)
        #expect(Set(names).count == names.count)
        #expect(Set(subtitles).count == subtitles.count)
    }
}

@Suite("Push categories")
struct PushCategoryTests {
    /// Mirrors `NotificationCatalogue::apnsCategoryIdentifiers()`. Category
    /// matching is case-sensitive; an identifier the client has not registered
    /// arrives with no action buttons at all.
    @Test("the registered identifiers match the backend")
    func identifiersMatchBackend() {
        let registered = Set(NotificationPreferences.PushCategory.allCases.map(\.rawValue))

        #expect(registered == ["INTEGRATION_ATTENTION", "INTEGRATION_STATUS", "SYSTEM"])
    }

    @Test("identifiers are SCREAMING_CASE")
    func identifiersAreScreamingCase() {
        for category in NotificationPreferences.PushCategory.allCases {
            #expect(category.rawValue == category.rawValue.uppercased())
        }
    }
}

@Suite("Notification preferences coding")
struct NotificationPreferencesCodingTests {
    @Test("decodes the real types the server now sends")
    func decodesRealTypes() throws {
        let json = """
        {
            "categories": {
                "integration_failed": false,
                "cookie_expiry_warning": true,
                "fetch_content_changed": false
            },
            "delivery_mode": "immediate",
            "digest_time": "08:00"
        }
        """

        let prefs = try JSONDecoder().decode(NotificationPreferences.self, from: Data(json.utf8))

        #expect(prefs.categories[.integrationFailed] == false)
        #expect(prefs.categories[.cookieExpiryWarning] == true)
        #expect(prefs.categories[.fetchContentChanged] == false)
    }

    @Test("an unknown category is dropped rather than failing the decode")
    func unknownCategoryIsDropped() throws {
        // A server that still sends a withdrawn category must not break the
        // settings screen for a client that has moved on.
        let json = """
        {
            "categories": {"anomaly": true, "integration_failed": false},
            "delivery_mode": "immediate"
        }
        """

        let prefs = try JSONDecoder().decode(NotificationPreferences.self, from: Data(json.utf8))

        #expect(prefs.categories.count == 1)
        #expect(prefs.categories[.integrationFailed] == false)
    }

    @Test("a full set round-trips, as the PATCH endpoint requires")
    func fullSetRoundTrips() throws {
        // The endpoint rejects a partial set unless delivery_mode is
        // work_hours, so the client must be able to send every type.
        var categories: [NotificationPreferences.Category: Bool] = [:]
        for category in NotificationPreferences.Category.allCases {
            categories[category] = true
        }
        categories[.integrationFailed] = false

        let encoded = try JSONEncoder().encode(
            NotificationPreferences(categories: categories, deliveryMode: .immediate, digestTime: "08:00")
        )
        let decoded = try JSONDecoder().decode(NotificationPreferences.self, from: encoded)

        #expect(decoded.categories.count == NotificationPreferences.Category.allCases.count)
        #expect(decoded.categories[.integrationFailed] == false)
        #expect(decoded.categories[.systemMaintenance] == true)
    }
}
