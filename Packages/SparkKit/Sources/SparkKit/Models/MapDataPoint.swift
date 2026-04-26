import Foundation

/// A single point shown on the map — a place, transaction, workout, or event
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

    public init(
        id: String,
        kind: Kind,
        lat: Double,
        lng: Double,
        title: String,
        subtitle: String? = nil,
        time: Date? = nil,
        service: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.lat = lat
        self.lng = lng
        self.title = title
        self.subtitle = subtitle
        self.time = time
        self.service = service
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

    /// Serialise as `lat1,lng1,lat2,lng2` per the backend contract.
    public var queryValue: String {
        "\(southWest.lat),\(southWest.lng),\(northEast.lat),\(northEast.lng)"
    }
}
