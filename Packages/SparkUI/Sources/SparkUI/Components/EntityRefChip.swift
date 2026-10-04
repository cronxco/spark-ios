import SwiftUI
import SparkKit

/// Inline reference pill — the iOS analogue of the web `<x-event-ref>` chip
/// card. Domain-tinted glass capsule with a leading glyph, the entity title,
/// and an optional service badge.
public struct EntityRefChip: View {
    public let reference: EntityReference

    public init(_ reference: EntityReference) {
        self.reference = reference
    }

    private var tint: Color { EntityPresentation.tint(for: reference) }

    public var body: some View {
        HStack(spacing: SparkSpacing.xs) {
            Image(systemName: EntityPresentation.icon(for: reference))
                .font(.system(size: 11, weight: .semibold))
                .opacity(0.8)
            Text(reference.title)
                .lineLimit(1)
            if let service = reference.service, !service.isEmpty {
                Text(service)
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.secondary)
            }
        }
        .font(SparkTypography.captionStrong)
        .foregroundStyle(tint)
        .padding(.horizontal, SparkSpacing.md - 2)
        .padding(.vertical, SparkSpacing.xs + 1)
        .sparkGlass(.capsule, tint: tint.opacity(0.15))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(reference.title)\(reference.service.map { ", \($0)" } ?? "")")
        .accessibilityAddTraits(.isButton)
    }
}

/// Wrapping cluster of `EntityRefChip`s with an optional leading label
/// (e.g. "Connecting:"), mirroring the web insight-block reference row.
/// Navigation-free: the host supplies `onTap`.
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
                        .font(SparkTypography.monoSmall)
                        .foregroundStyle(.secondary)
                }
                FlowLayout(spacing: SparkSpacing.xs + 2) {
                    ForEach(references) { reference in
                        Button {
                            onTap(reference)
                        } label: {
                            EntityRefChip(reference)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                onTap(reference)
                            } label: {
                                Label("Open", systemImage: "arrow.up.forward.app")
                            }
                        } preview: {
                            EntityPreviewCard(reference: reference)
                        }
                    }
                }
            }
        }
    }
}

/// Lightweight peek preview shown on long-press of a reference chip — the
/// iOS analogue of the web hover popover. Built only from the fields the
/// reference carries (no fetch), so it appears instantly.
public struct EntityPreviewCard: View {
    public let reference: EntityReference

    public init(reference: EntityReference) {
        self.reference = reference
    }

    private var tint: Color { EntityPresentation.tint(for: reference) }

    public var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            HStack(spacing: SparkSpacing.sm) {
                DomainGlyph(icon: EntityPresentation.icon(for: reference), tint: tint, size: 30)
                VStack(alignment: .leading, spacing: SparkSpacing.xxs) {
                    Text(reference.title)
                        .font(SparkTypography.bodyStrong)
                        .foregroundStyle(.primary)
                    Text(reference.type.rawValue.capitalized)
                        .font(SparkTypography.monoSmall)
                        .foregroundStyle(.secondary)
                }
            }
            if reference.service != nil || reference.domain != nil {
                HStack(spacing: SparkSpacing.sm) {
                    if let service = reference.service, !service.isEmpty {
                        Label(service, systemImage: "app.connected.to.app.below.fill")
                    }
                    if let domain = reference.domain, !domain.isEmpty {
                        Label(domain.capitalized, systemImage: "circle.fill")
                            .foregroundStyle(tint)
                    }
                }
                .font(SparkTypography.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(SparkSpacing.lg)
        .frame(minWidth: 240, alignment: .leading)
        .background(Color.sparkElevated)
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
