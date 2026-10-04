import SparkKit
@preconcurrency import UserNotifications

final class NotificationService: UNNotificationServiceExtension, @unchecked Sendable {
    private var handler: ((UNNotificationContent) -> Void)?
    private var bestAttempt: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.handler = contentHandler
        Self.queueShownReceipt(for: request)
        guard let mutable = request.content.mutableCopy() as? UNMutableNotificationContent else {
            contentHandler(request.content)
            return
        }
        bestAttempt = mutable

        if let domain = request.content.userInfo["spark.domain"] as? String {
            mutable.threadIdentifier = domain
        }

        guard let urlString = request.content.userInfo["spark.media_url"] as? String,
              let mediaURL = URL(string: urlString)
        else {
            contentHandler(mutable)
            return
        }

        // Access via self (which is @unchecked Sendable) to avoid Sendable
        // violations on local non-Sendable captures.
        let notificationID = request.identifier
        Task { [self] in
            if let attachment = await self.downloadAttachment(from: mediaURL, notificationID: notificationID) {
                self.bestAttempt?.attachments = [attachment]
            }
            if let h = self.handler, let b = self.bestAttempt {
                h(b)
            }
        }
    }

    override func serviceExtensionTimeWillExpire() {
        if let handler, let bestAttempt {
            handler(bestAttempt)
        }
    }

    // MARK: - Receipts

    /// Queues a "shown" receipt (decision N-8) for the app to send. Only
    /// queued here: a synchronous App Group write that cannot delay
    /// presentation, and no network call that would refresh the rotating
    /// token from a second process.
    private static func queueShownReceipt(for request: UNNotificationRequest) {
        guard let id = NotificationReceipt.notificationID(from: request.content.userInfo),
              let receipt = NotificationReceipt(notificationID: id, event: .shown)
        else { return }
        NotificationReceiptReporter.shared.enqueue([receipt])
    }

    // MARK: - Attachment download

    private func downloadAttachment(from url: URL, notificationID: String) async -> UNNotificationAttachment? {
        let cacheDir = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.co.cronx.sparkapp")?
            .appendingPathComponent("NotificationMedia", isDirectory: true)
            ?? FileManager.default.temporaryDirectory

        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        let ext = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
        let fileName = notificationID.replacingOccurrences(of: "/", with: "_") + "." + ext
        let localURL = cacheDir.appendingPathComponent(fileName)

        if FileManager.default.fileExists(atPath: localURL.path) {
            return try? UNNotificationAttachment(identifier: fileName, url: localURL)
        }

        do {
            let (tempURL, _) = try await URLSession.shared.download(from: url)
            if !FileManager.default.fileExists(atPath: localURL.path) {
                try FileManager.default.moveItem(at: tempURL, to: localURL)
            }
            return try UNNotificationAttachment(identifier: fileName, url: localURL)
        } catch {
            return nil
        }
    }
}
