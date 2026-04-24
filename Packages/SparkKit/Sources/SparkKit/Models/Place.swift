import Foundation

/// Mirrors `CompactPlaceResource` on the backend.
public struct Place: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let title: String
    public let type: String?
    public let latitude: Double?
    public let longitude: Double?
    public let address: String?
    public let category: String?

    public init(
        id: String,
        title: String,
        type: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        address: String? = nil,
        category: String? = nil
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.category = category
    }
}
