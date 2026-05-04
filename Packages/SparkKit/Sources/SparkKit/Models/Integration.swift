import Foundation

/// Mirrors `CompactIntegrationResource` on the backend.
public struct Integration: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let service: String
    public let name: String
    public let instanceType: String?
    public let status: String?

    public var statusValue: String {
        guard let status, !status.isEmpty else { return "unknown" }
        return status
    }

    enum CodingKeys: String, CodingKey {
        case id, service, name, status
        case instanceType = "instance_type"
    }

    public init(
        id: String,
        service: String,
        name: String,
        instanceType: String? = nil,
        status: String? = nil
    ) {
        self.id = id
        self.service = service
        self.name = name
        self.instanceType = instanceType
        self.status = status
    }
}
