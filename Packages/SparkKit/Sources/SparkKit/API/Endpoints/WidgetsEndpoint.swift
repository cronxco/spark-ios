import Foundation

public enum WidgetsEndpoint {
    /// GET /widgets/spend — today's spend summary for the Monzo spend widget.
    public static func spend() -> Endpoint<SpendWidget> {
        Endpoint(method: .get, path: "/widgets/spend")
    }
}
