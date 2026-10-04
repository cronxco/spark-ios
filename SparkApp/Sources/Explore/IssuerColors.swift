import SparkUI
import SwiftUI

/// Brand colours for the account issuers Spark knows about. One table, so an
/// issuer reads as the same colour in the account list and on its detail
/// screen. Unknown issuers fall back to the money domain colour.
enum IssuerColors {
    /// Light-to-dark pair for the issuer badge gradient.
    static func gradient(for provider: String?) -> (Color, Color) {
        switch provider?.lowercased() {
        case "monzo":    (Color(red: 0.953, green: 0.612, blue: 0.518), Color(red: 0.831, green: 0.369, blue: 0.271))
        case "starling": (Color(red: 0.565, green: 0.537, blue: 0.855), Color(red: 0.310, green: 0.278, blue: 0.647))
        case "amex":     (Color(red: 0.435, green: 0.584, blue: 0.780), Color(red: 0.176, green: 0.341, blue: 0.565))
        case "halifax":  (Color(red: 0.482, green: 0.612, blue: 0.800), Color(red: 0.204, green: 0.369, blue: 0.580))
        default:         (Color.domainMoney.opacity(0.7), Color.domainMoney)
        }
    }

    /// Single accent for tints and washes: the darker end of the badge.
    static func accent(for provider: String?) -> Color {
        gradient(for: provider).1
    }
}
