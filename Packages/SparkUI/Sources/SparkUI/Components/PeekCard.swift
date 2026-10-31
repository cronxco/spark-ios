import SwiftUI

/// The peek card behind a tag, a reference or a compact metric
/// (`docs/design-language.md` section 7.5): a transient surface with a 30%
/// tinted border all round, a glyph chip, the type as an eyebrow, the title, a
/// few facts and one full-width button onwards. Without a destination it says
/// so in a line of text instead of the button.
public struct PeekCard: View {
    public struct Fact: Hashable, Sendable {
        public let label: String
        public let value: String

        public init(_ label: String, _ value: String) {
            self.label = label
            self.value = value
        }
    }

    public struct Action {
        public let title: String
        public let perform: () -> Void

        public init(_ title: String, perform: @escaping () -> Void) {
            self.title = title
            self.perform = perform
        }
    }

    let icon: SparkIcon
    let tint: Color
    let eyebrow: String
    let title: String
    let facts: [Fact]
    let action: Action?
    let noDestination: String

    /// - Parameters:
    ///   - tint: the role colour for a tag or reference, the domain fill for
    ///     a metric. It colours the glyph chip, the border and the button.
    ///   - eyebrow: the type, in sentence case ("Music album").
    ///   - noDestination: the line shown when there is no `action`; empty
    ///     for a long-press preview, where the menu offers the way onwards.
    public init(
        icon: SparkIcon,
        tint: Color,
        eyebrow: String,
        title: String,
        facts: [Fact] = [],
        action: Action? = nil,
        noDestination: String = "Nothing to open for this yet."
    ) {
        self.icon = icon
        self.tint = tint
        self.eyebrow = eyebrow
        self.title = title
        self.facts = facts
        self.action = action
        self.noDestination = noDestination
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            HStack(alignment: .top, spacing: SparkSpacing.sm) {
                DomainGlyph(icon, tint: tint, size: 30)
                VStack(alignment: .leading, spacing: SparkSpacing.xxs) {
                    Text(eyebrow)
                        .font(SparkTypography.captionStrong)
                        .foregroundStyle(.secondary)
                    Text(title)
                        .font(SparkTypography.bodyStrong)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !facts.isEmpty {
                VStack(alignment: .leading, spacing: SparkSpacing.xs) {
                    ForEach(facts, id: \.self) { fact in
                        HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.sm) {
                            Text(fact.label)
                                .foregroundStyle(.secondary)
                            Spacer(minLength: SparkSpacing.sm)
                            Text(fact.value)
                                .foregroundStyle(.primary)
                                .monospacedDigit()
                                .multilineTextAlignment(.trailing)
                        }
                        .font(SparkTypography.bodySmall)
                        .accessibilityElement(children: .combine)
                    }
                }
            }

            if let action {
                Button(action: action.perform) {
                    Text(action.title)
                        .font(SparkTypography.bodyStrong)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(tint)
            } else if !noDestination.isEmpty {
                Text(noDestination)
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(SparkSpacing.lg)
        .frame(width: 288, alignment: .leading)
        .overlay {
            RoundedRectangle(cornerRadius: SparkRadii.md)
                .strokeBorder(tint.opacity(0.3), lineWidth: 1)
                .padding(1)
        }
    }
}

public extension View {
    /// Shows `content` as a peek card: a popover that stays a popover on
    /// iPhone (section 7.5), on the elevated surface.
    func sparkPeek<Peek: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Peek
    ) -> some View {
        #if os(iOS)
        popover(isPresented: isPresented, arrowEdge: .bottom) {
            content()
                .presentationCompactAdaptation(.popover)
                .presentationBackground(Color.sparkElevated)
        }
        #else
        sheet(isPresented: isPresented) {
            content()
        }
        #endif
    }
}

#Preview {
    PeekCard(
        icon: .album,
        tint: SparkRole.accent.fill,
        eyebrow: "Music album",
        title: "In Rainbows",
        facts: [.init("Integration", "Spotify"), .init("Domain", "Media")],
        action: .init("View tagged items") {}
    )
    .background(Color.sparkElevated)
}
