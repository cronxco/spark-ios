import Foundation

public enum DevicesEndpoint {
    /// GET /devices
    public static func list() -> Endpoint<[RegisteredDevice]> {
        Endpoint(method: .get, path: "/devices")
    }

    /// POST /devices — register this device. Returns the created record.
    public static func register(
        name: String,
        platform: String,
        apnsToken: String,
        appEnvironment: String,
        appVersion: String,
        bundleId: String,
        osVersion: String
    ) -> Endpoint<RegisteredDevice> {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let body = try? encoder.encode(RegisterRequest(
            name: name, platform: platform,
            apnsToken: apnsToken, appEnvironment: appEnvironment,
            appVersion: appVersion, bundleId: bundleId, osVersion: osVersion
        ))
        return Endpoint(method: .post, path: "/devices", body: body, contentType: "application/json")
    }

    /// DELETE /devices/{id}
    public static func revoke(id: String) -> Endpoint<EmptyResponse> {
        Endpoint(method: .delete, path: "/devices/\(id)")
    }

    private struct RegisterRequest: Encodable {
        let name: String
        let platform: String
        let apnsToken: String
        let appEnvironment: String
        let appVersion: String
        let bundleId: String
        let osVersion: String
    }
}
