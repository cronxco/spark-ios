/// SparkSync — background refresh, silent push, and real-time WebSocket.
///
/// Public surface:
/// - `DeltaSyncer`         fetch /sync/delta and write to SwiftData
/// - `BGTaskCoordinator`   BGAppRefreshTask + BGProcessingTask registration
/// - `SilentPushHandler`   silent push (content-available=1) handler
/// - `ReverbClient`        Pusher-protocol Reverb WebSocket actor
