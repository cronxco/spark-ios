import SwiftUI

/// Flint's mark — a warm gradient disc with a four-point star. Used wherever
/// Flint "speaks" in the UI (Up to Speed screens, the Flint tab, digest cards).
public struct FlintAvatar: View {
    public enum Size {
        case sm, md

        var diameter: CGFloat {
            switch self {
            case .sm: 22
            case .md: 26
            }
        }

        var glyph: CGFloat {
            switch self {
            case .sm: 11
            case .md: 13
            }
        }
    }

    private let size: Size

    public init(size: Size = .md) {
        self.size = size
    }

    public var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [.spark4, .ember5],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size.diameter, height: size.diameter)
            .overlay {
                Image(systemName: "sparkle")
                    .font(.system(size: size.glyph, weight: .bold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}

/// "Flint" attribution row — avatar + name + optional trailing meta (a time, a
/// state pill). Kept lightweight so screens can drop it above their headline.
public struct FlintByline: View {
    private let name: String
    private let meta: String?

    public init(_ name: String = "Flint", meta: String? = nil) {
        self.name = name
        self.meta = meta
    }

    public var body: some View {
        HStack(spacing: SparkSpacing.sm) {
            FlintAvatar(size: .sm)
            Text(name)
                .font(SparkTypography.captionStrong)
                .foregroundStyle(.secondary)
            if let meta {
                Text(meta)
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(meta.map { "\(name), \($0)" } ?? name)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: SparkSpacing.lg) {
        FlintAvatar(size: .sm)
        FlintAvatar(size: .md)
        FlintByline(meta: "07:27")
        FlintByline("Flint is asking")
    }
    .padding()
    .background(Color.sparkSurface)
}
