import SwiftUI

public struct LoadingShimmer: View {
    let cornerRadius: CGFloat
    @State private var phase: CGFloat = -1

    public init(cornerRadius: CGFloat = SparkRadii.md) {
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.sparkElevated)
                .overlay(
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.35), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .rotationEffect(.degrees(15))
                    .offset(x: phase * geo.size.width)
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .onAppear {
                    withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                        phase = 1.5
                    }
                }
        }
    }
}

public struct LoadingShimmerCard: View {
    public init() {}
    public var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            LoadingShimmer(cornerRadius: SparkRadii.sm).frame(height: 12).frame(maxWidth: 80)
            LoadingShimmer(cornerRadius: SparkRadii.sm).frame(height: 28).frame(maxWidth: 140)
            LoadingShimmer(cornerRadius: SparkRadii.sm).frame(height: 10).frame(maxWidth: 180)
        }
        .padding(SparkSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sparkGlass(.roundedRect(SparkRadii.lg))
    }
}

#Preview {
    VStack(spacing: SparkSpacing.md) {
        LoadingShimmerCard()
        LoadingShimmerCard()
    }
    .padding()
    .background(Color.sparkSurface)
}
