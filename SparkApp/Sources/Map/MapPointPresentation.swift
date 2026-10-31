import SparkKit
import SparkUI
import SwiftUI

/// How a map point looks, in one place: its glyph, tint and label.
/// Events take their domain (section 3.2). Places have no domain, so they
/// use the ocean `accent`, paired with the location glyph so it never reads
/// as a bare online tint.
extension MapDataPoint {
    var mapIcon: SparkIcon {
        switch kind {
        case .place: .place
        case .transaction: .payment
        case .workout: .workout
        case .event: domain == nil ? .place : .domain(domain)
        }
    }

    var mapTint: Color {
        switch kind {
        case .place: .domainOnline
        case .transaction: .domainMoney
        case .workout: .domainActivity
        case .event: domain == nil ? .domainOnline : EntityPresentation.tint(domain: domain)
        }
    }

    /// The text colour for the value on the stop card (section 3.6).
    var mapHero: Color {
        switch kind {
        case .place: .sparkHero(domain: "online")
        case .transaction: .sparkHero(domain: "money")
        case .workout: .sparkHero(domain: "activity")
        case .event: .sparkHero(domain: domain)
        }
    }

    var mapLabel: String {
        switch kind {
        case .place: "Place"
        case .transaction: "Payment"
        case .workout: "Workout"
        case .event: "Event"
        }
    }

    /// The card's context line: the address, or for a place, how often
    /// you've been.
    var mapContext: String? {
        if kind == .place, let visitCount {
            return visitCount == 1 ? "First visit" : "\(visitCount.formatted()) visits"
        }
        return address ?? service.map(Self.serviceName)
    }

    var detailRoute: DetailRoute {
        kind == .place ? .place(id: id) : .event(id: id)
    }

    private static func serviceName(_ service: String) -> String {
        service
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }
}
