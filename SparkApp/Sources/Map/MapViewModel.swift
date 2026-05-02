import Foundation
import MapKit
import Observation
import OSLog
import SparkKit

/// Drives the Map tab. Holds the visible region's points and the selected
/// time-of-day filter. Refetches when the region or date settle.
@MainActor
@Observable
final class MapViewModel {
    private let apiClient: APIClient
    private let logger = Logger(subsystem: "co.cronx.spark", category: "MapViewModel")

    // 0...1 fraction of the day — the timeline scrubber binds to this.
    var dayFraction: Double = 1.0
    var anchorDay: Date = .now

    var region: MKCoordinateRegion = MapViewModel.defaultRegion
    private(set) var points: [MapDataPoint] = []
    private(set) var isLoading: Bool = false
    private(set) var lastError: String?

    private var pendingFetch: Task<Void, Never>?

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    /// Coordinates that the timeline scrubber maps onto — the moment in the
    /// anchor day the user has scrubbed to.
    var selectedTime: Date {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: anchorDay)
        let interval: TimeInterval = 24 * 60 * 60
        return startOfDay.addingTimeInterval(interval * dayFraction)
    }

    /// Filtered subset of `points` whose `time` falls before the scrubber.
    /// Points without a time always render (places, etc.).
    var visiblePoints: [MapDataPoint] {
        let cutoff = selectedTime
        return points.filter { point in
            guard let time = point.time else { return true }
            return time <= cutoff
        }
    }

    func regionDidChange(_ new: MKCoordinateRegion) {
        region = new
        scheduleFetch()
    }

    func dayDidChange() {
        scheduleFetch()
    }

    /// Cancel any in-flight fetch and start a fresh one after a short debounce
    /// so panning + scrubbing don't hammer the backend.
    private func scheduleFetch() {
        pendingFetch?.cancel()
        pendingFetch = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await self?.fetch()
        }
    }

    func fetch() async {
        let bbox = boundingBox(for: region)
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await apiClient.request(
                MapEndpoint.points(bbox: bbox, date: anchorDay)
            )
            points = response
            lastError = nil
        } catch is CancellationError {
            return
        } catch APIError.notModified {
            // Cached payload is fine; keep current points.
        } catch {
            SparkObservability.captureHandled(error)
            logger.error("Map fetch failed: \(String(describing: error))")
            lastError = "Couldn’t load map data."
        }
    }

    private func boundingBox(for region: MKCoordinateRegion) -> BoundingBox {
        let half = (lat: region.span.latitudeDelta / 2, lng: region.span.longitudeDelta / 2)
        let sw = BoundingBox.Coordinate(
            lat: region.center.latitude - half.lat,
            lng: region.center.longitude - half.lng
        )
        let ne = BoundingBox.Coordinate(
            lat: region.center.latitude + half.lat,
            lng: region.center.longitude + half.lng
        )
        return BoundingBox(southWest: sw, northEast: ne)
    }

    /// Default to a wide UK view until the user pans or location fix arrives.
    static let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
        span: MKCoordinateSpan(latitudeDelta: 0.4, longitudeDelta: 0.4)
    )
}
