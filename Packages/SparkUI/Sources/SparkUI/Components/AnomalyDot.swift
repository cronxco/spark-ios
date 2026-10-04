import SwiftUI

/// Small pulsing status dot for anomaly indicators. Renders nothing when
/// `active` is false, so it can be placed in overlays without affecting layout.
public struct AnomalyDot: View {
    public let active: Bool
    public let size: CGFloat

    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.7

    public init(active: Bool, size: CGFloat = 7) {
        self.active = active
        self.size = size
    }

    public var body: some View {
        if active {
            ZStack {
                Circle()
                    .stroke(Color.sparkError.opacity(pulseOpacity), lineWidth: 1.5)
                    .frame(width: size * pulseScale, height: size * pulseScale)

                Circle()
                    .fill(Color.sparkError)
                    .frame(width: size, height: size)
            }
            .frame(width: size * 2.4, height: size * 2.4)
            .onAppear {
                withAnimation(
                    .easeOut(duration: 1.6).repeatForever(autoreverses: false)
                ) {
                    pulseScale = 2.4
                    pulseOpacity = 0
                }
            }
            .accessibilityLabel("Anomaly detected")
        }
    }
}
