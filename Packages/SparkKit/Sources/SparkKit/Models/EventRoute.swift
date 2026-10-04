import Foundation

/// Read-only GPS route returned by `/api/v1/mobile/events/{id}/route` for
/// events whose detail carries `has_route` (workouts). The backend drops
/// points without coordinates and thins long routes to at most 1,000 points.
public struct EventRoute: Codable, Sendable, Hashable {
    public struct Point: Codable, Sendable, Hashable {
        public let lat: Double
        public let lng: Double

        public init(lat: Double, lng: Double) {
            self.lat = lat
            self.lng = lng
        }
    }

    public let points: [Point]
    /// Usable points before thinning.
    public let totalPoints: Int
    public let distance: Double?
    public let distanceUnit: String?
    public let durationSeconds: Double?

    enum CodingKeys: String, CodingKey {
        case points, distance
        case totalPoints = "total_points"
        case distanceUnit = "distance_unit"
        case durationSeconds = "duration_seconds"
    }

    public init(
        points: [Point],
        totalPoints: Int? = nil,
        distance: Double? = nil,
        distanceUnit: String? = nil,
        durationSeconds: Double? = nil
    ) {
        self.points = points
        self.totalPoints = totalPoints ?? points.count
        self.distance = distance
        self.distanceUnit = distanceUnit
        self.durationSeconds = durationSeconds
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        points = try container.decodeIfPresent([Point].self, forKey: .points) ?? []
        totalPoints = try container.decodeIfPresent(Int.self, forKey: .totalPoints) ?? points.count
        distance = try container.decodeIfPresent(Double.self, forKey: .distance)
        distanceUnit = try container.decodeIfPresent(String.self, forKey: .distanceUnit)
        durationSeconds = try container.decodeIfPresent(Double.self, forKey: .durationSeconds)
    }

    /// A line needs two points; a single fix is not a route worth drawing.
    public var isDrawable: Bool { points.count >= 2 }

    /// The box around every point, or nil for an empty route.
    public var bounds: Bounds? {
        guard let first = points.first else { return nil }
        var bounds = Bounds(minLat: first.lat, maxLat: first.lat, minLng: first.lng, maxLng: first.lng)
        for point in points.dropFirst() {
            bounds.minLat = min(bounds.minLat, point.lat)
            bounds.maxLat = max(bounds.maxLat, point.lat)
            bounds.minLng = min(bounds.minLng, point.lng)
            bounds.maxLng = max(bounds.maxLng, point.lng)
        }
        return bounds
    }

    public struct Bounds: Sendable, Hashable {
        public var minLat: Double
        public var maxLat: Double
        public var minLng: Double
        public var maxLng: Double

        public var centerLat: Double { (minLat + maxLat) / 2 }
        public var centerLng: Double { (minLng + maxLng) / 2 }

        /// Span with `padding` added on each axis (0.3 = 30% larger), never
        /// smaller than `minimumSpan` so a short route is not zoomed in to nothing.
        public func span(padding: Double = 0.3, minimumSpan: Double = 0.005) -> (lat: Double, lng: Double) {
            (
                lat: max((maxLat - minLat) * (1 + padding), minimumSpan),
                lng: max((maxLng - minLng) * (1 + padding), minimumSpan)
            )
        }
    }
}
