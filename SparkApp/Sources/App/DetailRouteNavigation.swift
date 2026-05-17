import SparkKit
import SparkUI
import SwiftUI

/// Reference chip cluster for detail screens. Uses value-based
/// `NavigationLink`, so it pushes onto whatever stack presented the detail
/// view (matching every other in-detail navigation) instead of routing
/// globally and jumping tabs. Long-press shows the same peek as the Flint row.
struct EntityReferenceLinkRow: View {
    let label: String?
    let references: [EntityReference]

    var body: some View {
        if !references.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                if let label {
                    SparkDetailSectionHeader(label)
                }
                FlowLayout(spacing: SparkSpacing.xs + 2) {
                    ForEach(references) { reference in
                        if let route = reference.detailRoute {
                            NavigationLink(value: route) {
                                EntityRefChip(reference)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                NavigationLink(value: route) {
                                    Label("Open", systemImage: "arrow.up.forward.app")
                                }
                            } preview: {
                                EntityPreviewCard(reference: reference)
                            }
                        } else {
                            EntityRefChip(reference)
                        }
                    }
                }
            }
        }
    }
}

extension EntityReference {
    /// The in-stack destination this reference navigates to, if its type is
    /// one the app has a detail screen for.
    var detailRoute: DetailRoute? {
        switch type {
        case .event: .event(id: id)
        case .object: .object(id: id)
        case .block: .block(id: id)
        case .metric: .metric(identifier: id)
        case .place: .place(id: id)
        case .integration: .integration(service: id)
        case .unknown: nil
        }
    }
}

extension DeepLink {
    /// Maps a parsed universal link to an in-stack `DetailRoute`. Returns nil
    /// for non-entity links (today/day/auth) which are handled elsewhere.
    var detailRoute: DetailRoute? {
        switch self {
        case .event(let id): .event(id: id)
        case .object(let id): .object(id: id)
        case .block(let id): .block(id: id)
        case .metric(let identifier): .metric(identifier: identifier)
        case .place(let id): .place(id: id)
        case .integration(let service): .integration(service: service)
        case .today, .day, .authCallback: nil
        }
    }
}

extension View {
    /// Standard `DetailRoute` → detail-view destinations. Mirrors the switch
    /// in `DayPagerView`; applied wherever a tab owns its own stack.
    func sparkDetailDestinations() -> some View {
        navigationDestination(for: DetailRoute.self) { route in
            switch route {
            case .event(let id):
                EventDetailView(eventId: id)
            case .object(let id):
                ObjectDetailView(objectId: id)
            case .block(let id):
                BlockDetailView(blockId: id)
            case .metric(let identifier):
                MetricDetailView(identifier: identifier)
            case .place(let id):
                PlaceDetailView(placeId: id)
            case .integration(let service):
                IntegrationDetailView(integrationId: service)
            case .account(let id):
                AccountDetailView(accountId: id)
            }
        }
    }
}
