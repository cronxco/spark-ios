import Foundation

/// That a notification was shown, opened or tapped (decision N-8).
///
/// Operational telemetry only: a receipt carries the notification's id, the
/// event, when it happened and, for an action button, the action identifier.
/// It never carries the notification's title, body or any other content, and
/// the server rejects a receipt that does.
public struct NotificationReceipt: Codable, Sendable, Hashable {
    public enum Event: String, Codable, Sendable, CaseIterable {
        case shown
        case opened
        case tapped
    }

    /// How the user responded to a notification, from
    /// `UNNotificationResponse.actionIdentifier`.
    public enum Response: Sendable, Equatable {
        /// The notification itself was tapped (the default action).
        case defaultAction
        /// The notification was explicitly dismissed.
        case dismiss
        /// An action button. `opensApp` is whether the action brings the app
        /// forward (`UNNotificationActionOptions.foreground`).
        case action(identifier: String, opensApp: Bool)
    }

    public let notificationID: String
    public let event: Event
    public let occurredAt: Date
    public let action: String?

    /// `nil` when the id is not one the server issued (a UUID). An action
    /// identifier the server would reject is dropped rather than failing the
    /// receipt.
    public init?(notificationID: String, event: Event, occurredAt: Date = Date(), action: String? = nil) {
        guard UUID(uuidString: notificationID) != nil else { return nil }
        self.notificationID = notificationID
        self.event = event
        self.occurredAt = occurredAt
        self.action = action.flatMap(Self.validAction)
    }

    enum CodingKeys: String, CodingKey {
        case notificationID = "notification_id"
        case event
        case occurredAt = "occurred_at"
        case action
    }

    /// The Spark notification id from a push payload's `spark` envelope
    /// (`ApnsChannel::applySparkEnvelope`).
    public static func notificationID(from userInfo: [AnyHashable: Any]) -> String? {
        guard let envelope = userInfo["spark"] as? [String: Any],
              let id = envelope["notification_id"] as? String,
              !id.isEmpty
        else { return nil }
        return id
    }

    /// The receipts a response to a notification produces. Tapping the
    /// notification is `tapped` and `opened`; an action button is `tapped`
    /// with its identifier, and `opened` too when it brings the app forward.
    /// A dismissal reports nothing.
    public static func receipts(for response: Response, notificationID: String, at date: Date = Date()) -> [NotificationReceipt] {
        switch response {
        case .dismiss:
            return []
        case .defaultAction:
            return [
                NotificationReceipt(notificationID: notificationID, event: .tapped, occurredAt: date),
                NotificationReceipt(notificationID: notificationID, event: .opened, occurredAt: date),
            ].compactMap { $0 }
        case .action(let identifier, let opensApp):
            let tapped = NotificationReceipt(notificationID: notificationID, event: .tapped, occurredAt: date, action: identifier)
            let opened = opensApp
                ? NotificationReceipt(notificationID: notificationID, event: .opened, occurredAt: date, action: identifier)
                : nil
            return [tapped, opened].compactMap { $0 }
        }
    }

    private static func validAction(_ action: String) -> String? {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        guard !action.isEmpty,
              action.count <= 64,
              action.unicodeScalars.allSatisfy({ $0.isASCII && allowed.contains($0) })
        else { return nil }
        return action
    }
}

/// `POST /notifications/receipts` result counts.
public struct NotificationReceiptsResult: Decodable, Sendable, Equatable {
    public let recorded: Int
    public let unchanged: Int
    public let notFound: Int

    private enum RootKeys: String, CodingKey { case data }

    private enum CodingKeys: String, CodingKey {
        case recorded
        case unchanged
        case notFound = "not_found"
    }

    public init(from decoder: Decoder) throws {
        let root = try decoder.container(keyedBy: RootKeys.self)
        let container = try root.nestedContainer(keyedBy: CodingKeys.self, forKey: .data)
        recorded = try container.decode(Int.self, forKey: .recorded)
        unchanged = try container.decode(Int.self, forKey: .unchanged)
        notFound = try container.decode(Int.self, forKey: .notFound)
    }
}
