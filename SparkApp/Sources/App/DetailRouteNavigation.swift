import SparkKit
import SparkUI
import SwiftUI

/// Reference chip cluster for detail screens. A tap opens the reference's
/// peek card (`docs/design-language.md` section 7.5), whose button pushes the
/// detail onto whatever stack presented this screen, instead of routing
/// globally and jumping tabs. A long press keeps the preview.
struct EntityReferenceLinkRow: View {
    let label: String?
    let references: [EntityReference]

    @Environment(\.openDetailRoute) private var openDetailRoute

    var body: some View {
        if !references.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                if let label {
                    SparkDetailSectionHeader(label)
                }
                FlowLayout(spacing: SparkSpacing.xs + 2) {
                    ForEach(references) { reference in
                        if let route = reference.detailRoute, openDetailRoute == nil {
                            // A sheet's own stack has no opener: link straight
                            // through, as before the peek card.
                            NavigationLink(value: route) {
                                EntityRefChip(reference)
                            }
                            .buttonStyle(.plain)
                        } else {
                            PeekableEntityRefChip(reference, onOpen: opener(for: reference))
                        }
                    }
                }
            }
        }
    }

    private func opener(for reference: EntityReference) -> ((EntityReference) -> Void)? {
        guard let route = reference.detailRoute, let openDetailRoute else { return nil }
        return { _ in openDetailRoute(route) }
    }
}

/// A tag that opens its peek card on a tap; the card's button pushes the
/// tag's screen onto the current stack.
struct DetailTagChip: View {
    let tag: EventTag

    @Environment(\.openDetailRoute) private var openDetailRoute

    var body: some View {
        let route = DetailRoute.tag(id: tag.tagID, name: tag.name, type: tag.type)
        if let openDetailRoute {
            PeekableTagChip(tag) { openDetailRoute(route) }
        } else {
            // A sheet's own stack has no opener: link straight through.
            NavigationLink(value: route) { TagChip(tag) }
                .buttonStyle(.plain)
        }
    }
}

// MARK: - Opening a detail from a peek card

/// Pushes a `DetailRoute` onto the stack that owns the screen. A peek card
/// is a popover, outside the stack, so it can't use a `NavigationLink`; each
/// tab's stack installs one of these instead. Screens with no opener (a
/// sheet's own stack) link straight through instead.
struct OpenDetailRouteAction {
    let open: @MainActor (DetailRoute) -> Void

    @MainActor func callAsFunction(_ route: DetailRoute) {
        open(route)
    }
}

private struct OpenDetailRouteKey: EnvironmentKey {
    static var defaultValue: OpenDetailRouteAction? { nil }
}

extension EnvironmentValues {
    var openDetailRoute: OpenDetailRouteAction? {
        get { self[OpenDetailRouteKey.self] }
        set { self[OpenDetailRouteKey.self] = newValue }
    }
}

extension View {
    /// Lets peek cards inside this stack push onto `path`.
    func sparkOpensDetailRoutes(on path: Binding<[DetailRoute]>) -> some View {
        environment(\.openDetailRoute, OpenDetailRouteAction { route in
            if path.wrappedValue.last != route { path.wrappedValue.append(route) }
        })
    }

    /// Lets peek cards inside this stack push onto `path`.
    func sparkOpensDetailRoutes(on path: Binding<NavigationPath>) -> some View {
        environment(\.openDetailRoute, OpenDetailRouteAction { route in
            path.wrappedValue.append(route)
        })
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
        case .anomaly: .anomaly(id: id)
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
        case .anomaly(let id): .anomaly(id: id)
        case .integration(let service): .integration(service: service)
        case .tag(let name): .tag(name: name, type: nil)
        case .today, .day, .authCallback, .task, .project: nil
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
            case .anomaly(let id):
                AnomalyDetailView(anomalyId: id)
            case .integration(let service):
                IntegrationDetailView(integrationId: service)
            case .integrationReauth(let id):
                IntegrationDetailView(integrationId: id, reauthOnOpen: true)
            case .account(let id):
                AccountDetailView(accountId: id)
            case .tag(let id, let name, let type):
                TagDetailView(tagID: id, tagName: name, tagType: type)
            }
        }
    }
}
