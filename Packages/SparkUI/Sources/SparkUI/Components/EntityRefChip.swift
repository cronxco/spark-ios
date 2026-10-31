import SwiftUI
import SparkKit

/// A reference (`docs/design-language.md` section 7.5): a pill with a leading
/// glyph and the title, in its role colour on a 10% fill with a 20% border.
/// Text and glyph take the role's ink. The integration is shown only when a
/// screen asks for it with `showsService`.
public struct EntityRefChip: View {
    public let reference: EntityReference
    public let showsService: Bool

    public init(_ reference: EntityReference, showsService: Bool = false) {
        self.reference = reference
        self.showsService = showsService
    }

    private var service: String? {
        guard showsService, let service = reference.service, !service.isEmpty else { return nil }
        return service
    }

    public var body: some View {
        let role = reference.role
        HStack(spacing: SparkSpacing.xs) {
            SparkGlyph(reference.sparkIcon, size: 11, relativeTo: .subheadline)
                .opacity(0.7)
            Text(reference.title)
                .font(SparkTypography.bodySmall.weight(.medium))
                .lineLimit(1)
                .truncationMode(.tail)
            if let service {
                Text(service)
                    .font(SparkTypography.caption)
                    .lineLimit(1)
            }
        }
        .foregroundStyle(role.ink)
        .frame(maxWidth: 220, alignment: .leading)
        .padding(.horizontal, SparkSpacing.sm)
        .padding(.vertical, 2)
        .background(role.fill.opacity(0.10), in: .rect(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6).strokeBorder(role.fill.opacity(0.20), lineWidth: 1)
        }
        .contentShape(.rect(cornerRadius: 6))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([reference.title, service].compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(.isButton)
    }
}

/// A reference that opens its peek card on a tap (section 7.5). The card's
/// button calls `onOpen`; without one, the card says there is nothing to
/// open. A long press keeps the context-menu preview.
public struct PeekableEntityRefChip: View {
    public let reference: EntityReference
    public let showsService: Bool
    public let onOpen: ((EntityReference) -> Void)?

    @State private var isPeeking = false

    public init(
        _ reference: EntityReference,
        showsService: Bool = false,
        onOpen: ((EntityReference) -> Void)?
    ) {
        self.reference = reference
        self.showsService = showsService
        self.onOpen = onOpen
    }

    /// Closes the card before moving on, so it isn't left over the next
    /// screen.
    private var openFromPeek: (() -> Void)? {
        guard let onOpen else { return nil }
        let reference = reference
        return {
            isPeeking = false
            onOpen(reference)
        }
    }

    public var body: some View {
        Button {
            isPeeking.toggle()
        } label: {
            EntityRefChip(reference, showsService: showsService)
        }
        .buttonStyle(.plain)
        .sparkPeek(isPresented: $isPeeking) {
            EntityPeekCard(reference: reference, onOpen: openFromPeek)
        }
        .contextMenu {
            if let onOpen {
                Button {
                    onOpen(reference)
                } label: {
                    Label("Open", systemImage: "arrow.up.forward.app")
                }
            }
        } preview: {
            EntityPeekCard(reference: reference, onOpen: nil, isPreview: true)
                .background(Color.sparkElevated)
        }
    }
}

/// Wrapping cluster of references with an optional leading label
/// (e.g. "Connecting:"), mirroring the web insight-block reference row.
/// Navigation-free: a tap opens the peek card, whose button calls `onTap`.
public struct EntityRefChipRow: View {
    public let label: String?
    public let references: [EntityReference]
    public let onTap: (EntityReference) -> Void

    public init(
        label: String? = nil,
        references: [EntityReference],
        onTap: @escaping (EntityReference) -> Void
    ) {
        self.label = label
        self.references = references
        self.onTap = onTap
    }

    public var body: some View {
        if !references.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                if let label {
                    Text(label)
                        .font(SparkTypography.caption)
                        .foregroundStyle(.secondary)
                }
                FlowLayout(spacing: SparkSpacing.xs + 2) {
                    ForEach(references) { reference in
                        PeekableEntityRefChip(reference, onOpen: onTap)
                    }
                }
            }
        }
    }
}

/// A reference's peek card: its type, title and integration, and a button to
/// its detail screen. Built only from the fields the reference carries (no
/// fetch), so it appears at once.
public struct EntityPeekCard: View {
    public let reference: EntityReference
    public let onOpen: (() -> Void)?
    public let isPreview: Bool

    public init(reference: EntityReference, onOpen: (() -> Void)?, isPreview: Bool = false) {
        self.reference = reference
        self.onOpen = onOpen
        self.isPreview = isPreview
    }

    private var facts: [PeekCard.Fact] {
        var facts: [PeekCard.Fact] = []
        if let service = reference.service, !service.isEmpty {
            facts.append(.init("Integration", service))
        }
        if let domain = reference.domain, !domain.isEmpty {
            facts.append(.init("Domain", domain.capitalized))
        }
        return facts
    }

    public var body: some View {
        PeekCard(
            icon: reference.sparkIcon,
            tint: reference.role.fill,
            eyebrow: reference.typeLabel,
            title: reference.title,
            facts: facts,
            action: onOpen.map { PeekCard.Action("View \(reference.typeLabel.lowercased())", perform: $0) },
            noDestination: isPreview ? "" : "This \(reference.typeLabel.lowercased()) has no page to open."
        )
    }
}

/// The long-press preview of a reference, for screens that keep a context
/// menu without the tap-to-peek.
public struct EntityPreviewCard: View {
    public let reference: EntityReference

    public init(reference: EntityReference) {
        self.reference = reference
    }

    public var body: some View {
        EntityPeekCard(reference: reference, onOpen: nil, isPreview: true)
            .background(Color.sparkElevated)
    }
}

public extension EntityReference {
    /// The pill's role colour (section 7.5): objects by concept, everything
    /// else by its integration's domain.
    var role: SparkRole {
        type == .object ? SparkRole.forObjectType(domain) : SparkRole.forDomain(domain)
    }

    var sparkIcon: SparkIcon {
        switch type {
        case .place: .place
        case .anomaly: .anomaly
        case .metric: .chart
        case .object: .link
        case .event, .block, .integration, .unknown: .domain(domain)
        }
    }

    /// The type in sentence case, for the peek card's eyebrow.
    var typeLabel: String {
        switch type {
        case .event: "Event"
        case .object: "Object"
        case .block: "Block"
        case .metric: "Metric"
        case .place: "Place"
        case .anomaly: "Anomaly"
        case .integration: "Integration"
        case .unknown: "Reference"
        }
    }
}

#Preview {
    EntityRefChipRow(
        label: "Connecting:",
        references: [
            EntityReference(type: .event, id: "1", title: "Morning Walk", service: "Strava", domain: "activity"),
            EntityReference(type: .event, id: "2", title: "Slept 7h 42m", service: "Oura", domain: "health"),
            EntityReference(type: .object, id: "3", title: "Flat White", service: "Monzo", domain: "money"),
        ],
        onTap: { _ in }
    )
    .padding()
    .background(Color.sparkSurface)
}
