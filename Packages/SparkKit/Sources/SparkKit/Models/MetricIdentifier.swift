import Foundation

public enum MetricIdentifier {
    public static func from(event: Event) -> String {
        "\(event.service).\(event.action)"
    }

    public static func isValid(_ identifier: String) -> Bool {
        split(identifier) != nil
    }

    public static func split(_ identifier: String) -> (service: String, action: String)? {
        let parts = identifier.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let service = parts.first,
              let action = parts.last,
              !service.isEmpty,
              !action.isEmpty
        else {
            return nil
        }
        return (String(service), String(action))
    }
}
