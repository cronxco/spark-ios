import SparkKit
import SparkUI
import SwiftUI

/// A detail section heading (§12.2): the UI face, not Comfortaa, with an
/// optional glyph and a count written as "(N)".
struct SparkDetailSectionHeader: View {
    let title: String
    let trailing: String?
    var count: Int?
    var icon: SparkIcon?

    init(_ title: String, count: Int? = nil, icon: SparkIcon? = nil, trailing: String? = nil) {
        self.title = title
        self.count = count
        self.icon = icon
        self.trailing = trailing
    }

    private var text: String {
        guard let count else { return title }
        return "\(title) (\(count))"
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.sm) {
            if let icon {
                SparkGlyph(icon, size: 14, relativeTo: .headline)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

            Text(text)
                .font(Font.system(.headline))
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: SparkSpacing.sm)

            if let trailing, !trailing.isEmpty {
                Text(trailing)
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct SparkDetailLinkedRow: View {
    let title: String
    let subtitle: String?
    let trailing: String?
    var tint: Color = .sparkAccent
    /// Leading glyph, so rows of different kinds can be told apart at a glance.
    var icon: String?

    var body: some View {
        GlassCard(radius: SparkRadii.md, padding: SparkSpacing.md) {
            HStack(alignment: .center, spacing: SparkSpacing.md) {
                if let icon {
                    DomainGlyph(icon: icon, tint: tint, size: 28)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(SparkTypography.bodyStrong)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(SparkTypography.monoSmall)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                if let trailing, !trailing.isEmpty {
                    Text(trailing)
                        .font(SparkTypography.bodyStrong)
                        .foregroundStyle(tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// One row of "add" affordances at the end of a detail screen. It replaces
/// the empty Tags, Relationships and Notes sections, which on a sparse record
/// took more room than the data.
struct SparkDetailAddRow: View {
    struct Action: Identifiable {
        let title: String
        let systemImage: String
        let perform: @MainActor () -> Void

        var id: String { title }
    }

    let actions: [Action]

    var body: some View {
        FlowLayout(spacing: SparkSpacing.xs + 2) {
            ForEach(actions) { action in
                Button(action: action.perform) {
                    Label(action.title, systemImage: action.systemImage)
                        .font(SparkTypography.captionStrong)
                        .foregroundStyle(Color.sparkAccent)
                        .padding(.horizontal, SparkSpacing.md - 2)
                        .padding(.vertical, SparkSpacing.xs + 1)
                        .overlay {
                            Capsule()
                                .strokeBorder(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add \(action.title.lowercased())")
            }
        }
    }
}

/// Shows the entity's title in the navigation bar once the hero has scrolled
/// off, and nothing before that. A fixed "Object" or "Block" repeated what the
/// eyebrow already said and moved the toolbar between screens.
private struct SparkDetailInlineTitleModifier: ViewModifier {
    let title: String
    @State private var heroScrolledAway = false

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top > 140
            } action: { _, isAway in
                heroScrolledAway = isAway
            }
            .navigationTitle(heroScrolledAway ? title : "")
            .navigationBarTitleDisplayMode(.inline)
    }
}

extension View {
    /// Apply to the detail screen's `ScrollView`.
    func sparkDetailInlineTitle(_ title: String) -> some View {
        modifier(SparkDetailInlineTitleModifier(title: title))
    }
}

enum SparkDetailFormatters {
    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        return f
    }()

    static let shortTime: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    static let compactDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()

    static let compactDateTime: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM, HH:mm"
        return f
    }()
}

extension Color {
    static func domainTint(for domain: String) -> Color {
        EntityPresentation.tint(domain: domain)
    }
}
