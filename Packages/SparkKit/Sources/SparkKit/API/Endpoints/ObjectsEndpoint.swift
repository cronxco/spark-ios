import Foundation

public enum ObjectsEndpoint {
    /// GET /objects/{id}
    public static func detail(id: String) -> Endpoint<ObjectDetail> {
        Endpoint(method: .get, path: "/objects/\(id)")
    }
}
