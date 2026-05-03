import Foundation

extension String {
    /// Converts a snake_case action string to Title Case for display.
    /// "pot_transfer_to" → "Pot Transfer To"
    var humanisedAction: String {
        replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }
}
