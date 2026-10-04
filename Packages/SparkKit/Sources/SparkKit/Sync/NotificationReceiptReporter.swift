import Foundation
import OSLog

/// Reports notification receipts (decision N-8) without ever holding up
/// presentation.
///
/// A receipt is queued synchronously in the App Group `UserDefaults`, so it
/// survives the Notification Service Extension being torn down and the device
/// being offline, then sent in batches. Whatever fails to send stays queued
/// for the next report or `flush`, from the app or the extension. Repeats are
/// harmless: the server keeps the first time per event.
public final class NotificationReceiptReporter: @unchecked Sendable {
    public static let shared = NotificationReceiptReporter()

    /// The server accepts at most 50 receipts per request.
    static let batchSize = 50

    /// Oldest receipts are dropped beyond this, so an extended outage cannot
    /// grow the queue without bound.
    static let maxPending = 200

    private let defaults: UserDefaults
    private let key: String
    private let lock = NSLock()
    private var isFlushing = false
    private let logger = Logger(subsystem: "co.cronx.sparkapp", category: "NotificationReceipts")

    /// `UserDefaults` is thread-safe; `lock` serialises this process's
    /// read-modify-write of the queue.
    public init(defaults: UserDefaults = .sparkAppGroup, key: String = "spark.notificationReceipts.pending") {
        self.defaults = defaults
        self.key = key
    }

    /// Queue the receipts and try to send everything queued. Never throws.
    public func report(_ receipts: [NotificationReceipt], using client: APIClient) async {
        enqueue(receipts)
        await flush(using: client)
    }

    /// Queue receipts to send later. Synchronous, so a caller can queue before
    /// handing a notification back to the system.
    public func enqueue(_ receipts: [NotificationReceipt]) {
        guard !receipts.isEmpty else { return }
        lock.withLock {
            var queued = load()
            for receipt in receipts where !queued.contains(where: { $0.sameEvent(as: receipt) }) {
                queued.append(receipt)
            }
            save(Array(queued.suffix(Self.maxPending)))
        }
    }

    /// The receipts still waiting to be sent.
    public func pending() -> [NotificationReceipt] {
        lock.withLock { load() }
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
        lock.withLock {
            save(load().filter { queued in !sent.contains(where: { $0.sameEvent(as: queued) }) })
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

    private func load() -> [NotificationReceipt] {
        guard let data = defaults.data(forKey: key) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([NotificationReceipt].self, from: data)) ?? []
    }

    private func save(_ receipts: [NotificationReceipt]) {
        guard !receipts.isEmpty else {
            defaults.removeObject(forKey: key)
            return
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(receipts) {
            defaults.set(data, forKey: key)
        }
    }
}

private extension NotificationReceipt {
    func sameEvent(as other: NotificationReceipt) -> Bool {
        notificationID == other.notificationID && event == other.event
    }
}
