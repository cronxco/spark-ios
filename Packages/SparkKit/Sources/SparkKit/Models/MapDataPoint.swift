import Foundation

/// A single point shown on the map: a place, transaction, workout, or event
/// the user generated. Mirrors the backend's compact map-data resource.
public struct MapDataPoint: Codable, Sendable, Hashable, Identifiable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case place
        case transaction
        case workout
        case event
    }

    public let id: String
    public let kind: Kind
    public let lat: Double
    public let lng: Double
    public let title: String
    public let subtitle: String?
    public let time: Date?
    public let service: String?
    /// The event's domain (`money`, `health`, …). Nil for places, and for
    /// servers older than the field.
    public let domain: String?
    /// The street address, when the server has one.
    public let address: String?
    /// Places only: how often the place has been visited, when it was last
    /// visited, and its category, if it has one.
    public let visitCount: Int?
    public let lastVisitAt: Date?
    public let category: String?

    public init(
        id: String,
        kind: Kind,
        lat: Double,
        lng: Double,
        title: String,
        subtitle: String? = nil,
        time: Date? = nil,
        service: String? = nil,
        domain: String? = nil,
        address: String? = nil,
        visitCount: Int? = nil,
        lastVisitAt: Date? = nil,
        category: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.lat = lat
        self.lng = lng
        self.title = title
        self.subtitle = subtitle
        self.time = time
        self.service = service
        self.domain = domain
        self.address = address
        self.visitCount = visitCount
        self.lastVisitAt = lastVisitAt
        self.category = category
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, lat, lng, title, subtitle, time, service, domain, address, category
        case visitCount = "visit_count"
        case lastVisitAt = "last_visit_at"
    }

    /// When this point happened on the map's day: the event's time, or a
    /// place's most recent visit. The backend keeps only the latest visit,
    /// so a place is a stop on that day alone.
    public var stopTime: Date? {
        time ?? lastVisitAt
    }
}

/// Bounding box used to constrain a `/map/data` request to the visible region.
public struct BoundingBox: Sendable, Hashable {
    public let southWest: Coordinate
    public let northEast: Coordinate

    public init(southWest: Coordinate, northEast: Coordinate) {
        self.southWest = southWest
        self.northEast = northEast
    }

    public struct Coordinate: Sendable, Hashable {
        public let lat: Double
        public let lng: Double

        public init(lat: Double, lng: Double) {
            self.lat = lat
            self.lng = lng
        }
    }

    /// The whole world, for listing every saved place.
    public static let world = BoundingBox(
        southWest: Coordinate(lat: -90, lng: -180),
        northEast: Coordinate(lat: 90, lng: 180)
    )

    /// Serialise as `lat1,lng1,lat2,lng2` per the backend contract.
    public var queryValue: String {
        "\(southWest.lat),\(southWest.lng),\(northEast.lat),\(northEast.lng)"
    }
}

/// A coarse grid cell the backend sends instead of markers when a region
/// holds more than 500 points.
public struct MapCluster: Decodable, Sendable, Hashable, Identifiable {
    public let lat: Double
    public let lng: Double
    public let count: Int

    public var id: String { "\(lat),\(lng)" }

    public init(lat: Double, lng: Double, count: Int) {
        self.lat = lat
        self.lng = lng
        self.count = count
    }
}

public struct MapDataResponse: Decodable, Sendable {
    public struct Markers: Decodable, Sendable {
        public let events: [MapDataPoint]
        public let places: [MapDataPoint]

        public init(events: [MapDataPoint] = [], places: [MapDataPoint] = []) {
            self.events = events
            self.places = places
        }
    }

    public let markers: Markers
    public let clusters: [MapCluster]

    public var allPoints: [MapDataPoint] { markers.events + markers.places }

    public init(markers: Markers = Markers(), clusters: [MapCluster] = []) {
        self.markers = markers
        self.clusters = clusters
    }

    enum CodingKeys: String, CodingKey {
        case markers, clusters
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // A clustered response sends `"markers": []` (PHP's empty array)
        // rather than an object. Any other shape still has to decode.
        if (try? container.decode([MapDataPoint].self, forKey: .markers)) != nil {
            markers = Markers()
        } else {
            markers = try container.decodeIfPresent(Markers.self, forKey: .markers) ?? Markers()
        }
        clusters = try container.decodeIfPresent([MapCluster].self, forKey: .clusters) ?? []
    }
}
