import UserNotifications

/// Phase 1 stub. Real rich-notification mutation lands in Phase 2.
final class NotificationService: UNNotificationServiceExtension {
    private var handler: ((UNNotificationContent) -> Void)?
    private var bestAttempt: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.handler = contentHandler
        bestAttempt = request.content.mutableCopy() as? UNMutableNotificationContent
        if let bestAttempt {
            contentHandler(bestAttempt)
        } else {
            contentHandler(request.content)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        if let handler, let bestAttempt {
            handler(bestAttempt)
        }
    }
}
