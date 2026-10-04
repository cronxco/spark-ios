import Foundation
import OSLog

/// Reports notification receipts (decision N-8) without ever holding up
/// presentation.
///
/// Each receipt is queued synchronously as its own file in the App Group
/// container, so it survives the Notification Service Extension being torn
/// down and the device being offline, then sent in batches. One file per
/// notification and event means the app and the extension never rewrite a
/// shared queue: a write creates a file and a send deletes the files it sent,
/// so neither process can overwrite the other's change. Whatever fails to
/// send stays queued for the next report or `flush`. Repeats are harmless:
/// the server keeps the first time per event.
public final class NotificationReceiptReporter: @unchecked Sendable {
    public static let shared = NotificationReceiptReporter()

    /// The server accepts at most 50 receipts per request.
    static let batchSize = 50

    /// Oldest receipts are dropped beyond this, so an extended outage cannot
    /// grow the queue without bound.
    static let maxPending = 200

    private let directory: URL?
    private let fileManager = FileManager.default
    private let lock = NSLock()
    private var isFlushing = false
    private var lastQueuedAt: TimeInterval = 0
    private let logger = Logger(subsystem: "co.cronx.sparkapp", category: "NotificationReceipts")

    /// `directory` defaults to `NotificationReceipts` in the App Group
    /// container; `lock` only guards this process's flush flag and clock.
    public init(directory: URL? = NotificationReceiptReporter.defaultDirectory()) {
        self.directory = directory
    }

    /// The shared queue directory, or nil when the App Group is unavailable.
    public static func defaultDirectory() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: SparkDataStore.appGroupIdentifier)?
            .appendingPathComponent("NotificationReceipts", isDirectory: true)
    }

    /// Queue the receipts and try to send everything queued. Never throws.
    public func report(_ receipts: [NotificationReceipt], using client: APIClient) async {
        enqueue(receipts)
        await flush(using: client)
    }

    /// Queue receipts to send later. Synchronous, so a caller can queue before
    /// handing a notification back to the system. The first receipt per
    /// notification and event wins.
    public func enqueue(_ receipts: [NotificationReceipt]) {
        guard !receipts.isEmpty, let directory else { return }
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        for receipt in receipts {
            let url = fileURL(for: receipt, in: directory)
            guard !fileManager.fileExists(atPath: url.path) else { continue }
            let entry = QueuedReceipt(receipt: receipt, queuedAt: nextQueuedAt())
            if let data = try? encoder.encode(entry) {
                try? data.write(to: url, options: .atomic)
            }
        }
        trimToLimit()
    }

    /// The receipts still waiting to be sent, oldest first.
    public func pending() -> [NotificationReceipt] {
        queued().map(\.entry.receipt)
    }

    /// Send queued receipts in batches until the queue is empty or a send
    /// fails in a way worth retrying later.
    public func flush(using client: APIClient) async {
        guard beginFlush() else { return }
        defer { endFlush() }

        while true {
            let batch = Array(pending().prefix(Self.batchSize))
            guard !batch.isEmpty else { return }

            do {
                _ = try await client.request(NotificationsEndpoint.recordReceipts(batch))
                remove(batch)
            } catch let error as APIError where Self.isPermanentRejection(error) {
                // Retrying a request the server refused as invalid cannot
                // succeed, so it is dropped rather than blocking the queue.
                logger.error("Dropped \(batch.count) notification receipts: \(error.localizedDescription, privacy: .public)")
                remove(batch)
            } catch {
                return
            }
        }
    }

    /// A client error other than auth, timeout or rate limiting.
    static func isPermanentRejection(_ error: APIError) -> Bool {
        guard case .httpStatus(let status, _, _) = error else { return false }
        return (400..<500).contains(status) && ![401, 403, 408, 429].contains(status)
    }

    private func remove(_ sent: [NotificationReceipt]) {
        guard let directory else { return }
        for receipt in sent {
            try? fileManager.removeItem(at: fileURL(for: receipt, in: directory))
        }
    }

    private func trimToLimit() {
        let entries = queued()
        guard entries.count > Self.maxPending else { return }
        for stale in entries.prefix(entries.count - Self.maxPending) {
            try? fileManager.removeItem(at: stale.url)
        }
    }

    /// Increases strictly within this process, so receipts queued in one
    /// call keep their order.
    private func nextQueuedAt() -> TimeInterval {
        lock.withLock {
            lastQueuedAt = max(Date().timeIntervalSince1970, lastQueuedAt + 0.000_001)
            return lastQueuedAt
        }
    }

    private func beginFlush() -> Bool {
        lock.withLock {
            guard !isFlushing else { return false }
            isFlushing = true
            return true
        }
    }

    private func endFlush() {
        lock.withLock { isFlushing = false }
    }

    private func queued() -> [(url: URL, entry: QueuedReceipt)] {
        guard let directory,
              let urls = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return urls
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url),
                      let entry = try? decoder.decode(QueuedReceipt.self, from: data)
                else { return nil }
                return (url, entry)
            }
            .sorted { $0.entry.queuedAt < $1.entry.queuedAt }
    }

    private func fileURL(for receipt: NotificationReceipt, in directory: URL) -> URL {
        directory.appendingPathComponent("\(receipt.notificationID).\(receipt.event.rawValue).json")
    }
}

private struct QueuedReceipt: Codable {
    let receipt: NotificationReceipt
    let queuedAt: TimeInterval
}
