import Foundation

public enum BlocksEndpoint {
    /// GET /blocks/{id}
    public static func detail(id: String) -> Endpoint<BlockDetail> {
        Endpoint(method: .get, path: "/blocks/\(id)")
    }
}
