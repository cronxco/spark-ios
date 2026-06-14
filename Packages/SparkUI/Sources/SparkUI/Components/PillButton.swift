import SwiftUI

public struct PillButton: View {
    let title: String
    let systemImage: String?
    let tint: Color
    let foreground: Color
    let action: () -> Void

    public init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.tint = .sparkAccent
        self.foreground = .sparkOnAccent
        self.action = action
    }

    public init(
        _ title: String,
        systemImage: String? = nil,
        tint: Color,
        foreground: Color = .white,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.foreground = foreground
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: SparkSpacing.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(SparkTypography.bodyStrong)
            }
            .padding(.horizontal, SparkSpacing.xl)
            .padding(.vertical, SparkSpacing.md)
            .foregroundStyle(foreground)
            .sparkGlass(.capsule, tint: tint)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: SparkSpacing.md) {
        PillButton("Sign in with Spark", systemImage: "sparkles") {}
        PillButton("Retry", tint: .sparkNegative) {}
    }
    .padding()
    .background(Color.sparkSurface)
}
