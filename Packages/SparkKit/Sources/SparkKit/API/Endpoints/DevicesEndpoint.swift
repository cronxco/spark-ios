import Foundation

public enum DevicesEndpoint {
    /// GET /devices
    public static func list() -> Endpoint<[RegisteredDevice]> {
        Endpoint(method: .get, path: "/devices")
    }

    /// POST /devices — register this device. Returns the created record.
    public static func register(name: String, platform: String) -> Endpoint<RegisteredDevice> {
        let body = try? JSONEncoder().encode(RegisterRequest(name: name, platform: platform))
        return Endpoint(method: .post, path: "/devices", body: body, contentType: "application/json")
    }

    /// DELETE /devices/{id}
    public static func revoke(id: String) -> Endpoint<EmptyResponse> {
        Endpoint(method: .delete, path: "/devices/\(id)")
    }

    private struct RegisterRequest: Encodable {
        let name: String
        let platform: String
    }
}
