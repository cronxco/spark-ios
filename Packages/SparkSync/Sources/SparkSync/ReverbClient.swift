import Foundation
import OSLog
import SparkKit

/// Pusher-protocol WebSocket client connecting to Laravel Reverb.
///
/// Connects to `wss://{host}/app/{key}?protocol=7`, subscribes to
/// `private-App.Models.User.{userId}` after authenticating via
/// `POST /broadcasting/auth`, then forwards decoded broadcast events
/// to any registered handlers.
///
/// **Lifecycle**: call `connect(userId:)` on `.sceneDidBecomeActive` and
/// `disconnect()` on `.sceneWillResignActive`. The actor serialises all
/// state mutations; callers can await these methods from any context.
///
/// **Deduplication**: a rolling 100-entry set prevents double-applying the
/// same broadcast when both a silent push and a WebSocket message arrive.
public actor ReverbClient {

    // MARK: - Types

    /// A decoded broadcast from the server. Handlers receive raw JSON `data`
    /// so they can decode only what they care about.
    public struct BroadcastEvent: Sendable {
        public let eventName: String
        public let channel: String
        public let data: Data
    }

    public typealias EventHandler = @Sendable (BroadcastEvent) async -> Void

    // MARK: - Private state

    private let environment: APIEnvironment
    private let tokenStore: KeychainTokenStore
    private let session: URLSession
    private let logger = Logger(subsystem: "co.cronx.spark", category: "ReverbClient")

    private var socketTask: URLSessionWebSocketTask?
    private var receiveLoopTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var socketId: String?
    private var currentUserId: String?
    private var isConnected = false
    private var isStopped = false

    private var handlers: [EventHandler] = []
    private var seenBroadcastIds: [String] = []  // rolling 100-entry dedup queue

    private var reconnectDelay: TimeInterval = 1

    // MARK: - Init

    public init(
        environment: APIEnvironment = .current(),
        tokenStore: KeychainTokenStore,
        session: URLSession = .shared
    ) {
        self.environment = environment
        self.tokenStore = tokenStore
        self.session = session
    }

    // MARK: - Public API

    /// Register a handler that receives every broadcast event. Thread-safe.
    public func addHandler(_ handler: @escaping EventHandler) {
        handlers.append(handler)
    }

    /// Open the WebSocket and subscribe to the user's private channel.
    public func connect(userId: String) async {
        isStopped = false
        currentUserId = userId
        reconnectDelay = 1
        await openSocket()
    }

    /// Tear down the WebSocket permanently. Does not reconnect.
    public func disconnect() async {
        isStopped = true
        currentUserId = nil
        tearDown()
        logger.info("Reverb disconnected by caller")
    }

    // MARK: - Connection lifecycle

    private func openSocket() async {
        tearDown()
        let url = environment.reverbWebSocketURL
        var request = URLRequest(url: url)
        request.setValue("permessage-deflate", forHTTPHeaderField: "Sec-WebSocket-Extensions")
        socketTask = session.webSocketTask(with: request)
        socketTask?.resume()
        logger.info("Reverb socket opened → \(url.absoluteString, privacy: .public)")
        await captureSocketTelemetry(url: url, outcome: .success)
        startReceiveLoop()
        startPingLoop()
    }

    private func tearDown() {
        receiveLoopTask?.cancel()
        pingTask?.cancel()
        reconnectTask?.cancel()
        receiveLoopTask = nil
        pingTask = nil
        reconnectTask = nil
        socketTask?.cancel(with: .normalClosure, reason: nil)
        socketTask = nil
        socketId = nil
        isConnected = false
    }

    // MARK: - Receive loop

    private func startReceiveLoop() {
        receiveLoopTask = Task {
            guard let task = socketTask else { return }
            while !Task.isCancelled {
                do {
                    let message = try await task.receive()
                    await handleMessage(message)
                } catch {
                    if Task.isCancelled { return }
                    logger.warning("Reverb receive error: \(error, privacy: .public)")
                    await captureSocketTelemetry(
                        url: task.currentRequest?.url ?? environment.reverbWebSocketURL,
                        outcome: .transportError,
                        errorDescription: String(describing: error)
                    )
                    scheduleReconnect()
                    return
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) async {
        let text: String
        switch message {
        case .string(let s): text = s
        case .data(let d): text = String(decoding: d, as: UTF8.self)
        @unknown default: return
        }

        guard
            let data = text.data(using: .utf8),
            let envelope = try? JSONDecoder().decode(PusherEnvelope.self, from: data)
        else { return }

        switch envelope.event {
        case "pusher:connection_established":
            await handleConnectionEstablished(envelope.dataString)

        case "pusher:ping":
            try? await socketTask?.send(.string(#"{"event":"pusher:pong","data":{}}"#))

        case "pusher_internal:subscription_succeeded":
            isConnected = true
            reconnectDelay = 1
            logger.info("Reverb subscribed to \(envelope.channel ?? "?", privacy: .public)")

        case "pusher:error":
            logger.error("Reverb server error: \(envelope.dataString ?? "", privacy: .public)")

        default:
            guard let channel = envelope.channel,
                  let dataStr = envelope.dataString,
                  let dataBytes = dataStr.data(using: .utf8)
            else { return }

            let dedupKey = "\(envelope.event)|" + dataStr.prefix(200)
            guard !isDuplicate(dedupKey) else { return }

            let broadcast = BroadcastEvent(
                eventName: envelope.event,
                channel: channel,
                data: dataBytes
            )
            for handler in handlers {
                await handler(broadcast)
            }
        }
    }

    private func handleConnectionEstablished(_ dataString: String?) async {
        guard
            let raw = dataString,
            let innerData = raw.data(using: .utf8),
            let inner = try? JSONDecoder().decode(ConnectionData.self, from: innerData)
        else { return }

        socketId = inner.socketId
        logger.info("Reverb connection established, socket_id=\(inner.socketId, privacy: .public)")

        if let userId = currentUserId {
            await subscribeToPrivateChannel(userId: userId)
        }
    }

    // MARK: - Private channel auth

    private func subscribeToPrivateChannel(userId: String) async {
        let channel = "private-App.Models.User.\(userId)"

        guard
            let socketId,
            let auth = await fetchChannelAuth(channel: channel, socketId: socketId)
        else {
            logger.error("Reverb: channel auth failed for \(channel, privacy: .public)")
            return
        }

        let payload = SubscribePayload(channel: channel, auth: auth)
        guard
            let payloadData = try? JSONEncoder().encode(payload),
            let payloadString = String(data: payloadData, encoding: .utf8)
        else { return }

        let message = #"{"event":"pusher:subscribe","data":"# + payloadString + "}"
        try? await socketTask?.send(.string(message))
        logger.info("Reverb: subscribe sent for \(channel, privacy: .public)")
    }

    private func fetchChannelAuth(channel: String, socketId: String) async -> String? {
        guard let token = await tokenStore.accessToken() else { return nil }

        var components = URLComponents(url: environment.baseURL, resolvingAgainstBaseURL: false)!
        components.path = "/broadcasting/auth"
        components.queryItems = nil
        let authURL = components.url!
        var request = URLRequest(url: authURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        request.httpBody = "channel_name=\(channel)&socket_id=\(socketId)".data(using: .utf8)

        let startedAt = Date()
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let http = response as? HTTPURLResponse
            await captureAuthTelemetry(
                request: request,
                response: http,
                data: data,
                startedAt: startedAt,
                outcome: http?.statusCode == 200 ? .success : .httpError
            )
            guard http?.statusCode == 200 else { return nil }
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            return authResponse.auth
        } catch {
            logger.error("Reverb auth request failed: \(error, privacy: .public)")
            await captureAuthTelemetry(
                request: request,
                response: nil,
                data: nil,
                startedAt: startedAt,
                outcome: .transportError,
                errorDescription: String(describing: error)
            )
            return nil
        }
    }

    private func captureAuthTelemetry(
        request: URLRequest,
        response: HTTPURLResponse?,
        data: Data?,
        startedAt: Date,
        outcome: APITelemetryEvent.Outcome,
        errorDescription: String? = nil
    ) async {
        await APITelemetry.shared.capture(
            APITelemetryEvent(
                operation: "http.client.reverb_auth",
                method: request.httpMethod ?? "POST",
                url: APITelemetryRedactor.url(request.url ?? environment.reverbHTTPBaseURL),
                endpointPath: "/broadcasting/auth",
                requiresAuth: true,
                requestHeaders: APITelemetryRedactor.headers(request.allHTTPHeaderFields ?? [:]),
                requestBody: APITelemetryRedactor.body(request.httpBody, contentType: request.value(forHTTPHeaderField: "Content-Type")),
                statusCode: response?.statusCode,
                responseHeaders: APITelemetryRedactor.headers(response?.stringHeaderFields ?? [:]),
                responseBody: APITelemetryRedactor.body(data, contentType: response?.value(forHTTPHeaderField: "Content-Type")),
                responseSizeBytes: data?.count ?? 0,
                durationMillis: Date().timeIntervalSince(startedAt) * 1_000,
                outcome: outcome,
                errorDescription: errorDescription
            )
        )
    }

    private func captureSocketTelemetry(
        url: URL,
        outcome: APITelemetryEvent.Outcome,
        errorDescription: String? = nil
    ) async {
        await APITelemetry.shared.capture(
            APITelemetryEvent(
                operation: "websocket.reverb",
                method: "WEBSOCKET",
                url: APITelemetryRedactor.url(url),
                endpointPath: "/app/{key}",
                requiresAuth: false,
                durationMillis: 0,
                outcome: outcome,
                errorDescription: errorDescription
            )
        )
    }

    // MARK: - Ping loop

    private func startPingLoop() {
        pingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                if Task.isCancelled { return }
                try? await socketTask?.send(.string(#"{"event":"pusher:ping","data":{}}"#))
            }
        }
    }

    // MARK: - Reconnect

    private func scheduleReconnect() {
        guard !isStopped, currentUserId != nil else { return }
        let delay = reconnectDelay
        reconnectDelay = min(reconnectDelay * 2, 30)
        logger.info("Reverb reconnecting in \(delay, format: .fixed(precision: 0), privacy: .public)s")
        reconnectTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            if Task.isCancelled || isStopped { return }
            await openSocket()
        }
    }

    // MARK: - Deduplication

    private func isDuplicate(_ key: String) -> Bool {
        if seenBroadcastIds.contains(key) { return true }
        seenBroadcastIds.append(key)
        if seenBroadcastIds.count > 100 {
            seenBroadcastIds.removeFirst()
        }
        return false
    }

    // MARK: - Codable helpers (internal wire types)

    private struct PusherEnvelope: Decodable {
        let event: String
        let channel: String?
        let data: PusherData?

        var dataString: String? {
            switch data {
            case .string(let s): return s
            case .object: return nil
            case nil: return nil
            }
        }

        enum PusherData: Decodable {
            case string(String)
            case object

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let s = try? container.decode(String.self) {
                    self = .string(s)
                } else {
                    self = .object
                }
            }
        }
    }

    private struct ConnectionData: Decodable {
        let socketId: String
        enum CodingKeys: String, CodingKey { case socketId = "socket_id" }
    }

    private struct SubscribePayload: Encodable {
        let channel: String
        let auth: String
    }

    private struct AuthResponse: Decodable {
        let auth: String
    }
}

private extension HTTPURLResponse {
    var stringHeaderFields: [String: String] {
        Dictionary(uniqueKeysWithValues: allHeaderFields.compactMap { key, value in
            guard let key = key as? String else { return nil }
            return (key, String(describing: value))
        })
    }
}
