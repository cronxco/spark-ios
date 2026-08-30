import Foundation

public enum DevicesEndpoint {
    /// GET /devices
    public static func list() -> Endpoint<DevicesListResponse> {
        Endpoint(method: .get, path: "/devices")
    }

    /// POST /devices — register this device. Success is enough; the app does not consume the response body.
    public static func register(
        name: String,
        platform: String,
        apnsToken: String,
        appEnvironment: String,
        appVersion: String,
        bundleId: String,
        osVersion: String
    ) -> Endpoint<DeviceRegistrationResponse> {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let body = try? encoder.encode(RegisterRequest(
            deviceName: name, platform: platform,
            apnsToken: apnsToken, appEnvironment: appEnvironment,
            appVersion: appVersion, bundleId: bundleId, osVersion: osVersion
        ))
        return Endpoint(method: .post, path: "/devices", body: body, contentType: "application/json")
    }

    /// POST /devices/test — send a diagnostic APNs notification to this user.
    public static func sendTestPush() -> Endpoint<EmptyResponse> {
        Endpoint(method: .post, path: "/devices/test")
    }

    /// DELETE /devices/{id}
    public static func revoke(id: String) -> Endpoint<EmptyResponse> {
        Endpoint(method: .delete, path: "/devices/\(id)")
    }

    private struct RegisterRequest: Encodable {
        let deviceName: String
        let platform: String
        let apnsToken: String
        let appEnvironment: String
        let appVersion: String
        let bundleId: String
        let osVersion: String
    }
}

/// Newer mobile API responses wrap the device collection in `devices` while
/// older deployments return the array directly. Support both during rollout.
public struct DevicesListResponse: Decodable, Sendable {
    public let devices: [RegisteredDevice]

    public init(from decoder: Decoder) throws {
        if let devices = try? decoder.singleValueContainer().decode([RegisteredDevice].self) {
            self.devices = devices
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        devices = try container.decode([RegisteredDevice].self, forKey: .devices)
    }

    private enum CodingKeys: String, CodingKey { case devices }
}

public struct DeviceRegistrationResponse: Decodable, Sendable {
    public let id: String
    public let deviceType: String
    public let endpoint: String
    public let appEnvironment: String

    enum CodingKeys: String, CodingKey {
        case id
        case deviceType = "device_type"
        case endpoint
        case appEnvironment = "app_environment"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let stringID = try? container.decode(String.self, forKey: .id) {
            id = stringID
        } else {
            id = String(try container.decode(Int.self, forKey: .id))
        }
        deviceType = try container.decode(String.self, forKey: .deviceType)
        endpoint = try container.decode(String.self, forKey: .endpoint)
        appEnvironment = try container.decode(String.self, forKey: .appEnvironment)
    }
}
