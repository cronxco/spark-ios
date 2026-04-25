import SwiftUI

/// Apple-style concentric Move / Exercise / Stand rings. Drawn with `Canvas`
/// so the geometry is crisp at every scale and the component has zero layout
/// cost. Colours match the Activity app for instant recognition.
public struct ActivityRings: View {
    public let move: Double
    public let exercise: Double
    public let stand: Double
    public let lineWidth: CGFloat
    public let spacing: CGFloat

    public init(
        move: Double,
        exercise: Double,
        stand: Double,
        lineWidth: CGFloat = 10,
        spacing: CGFloat = 4
    ) {
        self.move = move
        self.exercise = exercise
        self.stand = stand
        self.lineWidth = lineWidth
        self.spacing = spacing
    }

    public var body: some View {
        Canvas { ctx, size in
            let radius = min(size.width, size.height) / 2
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            draw(progress: move, color: Self.moveColor, ringRadius: radius - lineWidth / 2,
                 lineWidth: lineWidth, center: center, in: &ctx)

            let exR = radius - lineWidth - spacing - lineWidth / 2
            draw(progress: exercise, color: Self.exerciseColor, ringRadius: exR,
                 lineWidth: lineWidth, center: center, in: &ctx)

            let stR = radius - 2 * (lineWidth + spacing) - lineWidth / 2
            draw(progress: stand, color: Self.standColor, ringRadius: stR,
                 lineWidth: lineWidth, center: center, in: &ctx)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Activity rings")
        .accessibilityValue(
            "Move \(Int((move * 100).rounded())) percent, exercise \(Int((exercise * 100).rounded())) percent, stand \(Int((stand * 100).rounded())) percent"
        )
    }

    private func draw(
        progress: Double,
        color: Color,
        ringRadius: CGFloat,
        lineWidth: CGFloat,
        center: CGPoint,
        in ctx: inout GraphicsContext
    ) {
        guard ringRadius > 0 else { return }

        // Faint full-track underlay.
        var track = Path()
        track.addArc(center: center, radius: ringRadius,
                     startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
        ctx.stroke(track, with: .color(color.opacity(0.18)),
                   style: StrokeStyle(lineWidth: lineWidth))

        guard progress > 0 else { return }

        let clamped = min(progress, 1.0)
        var arc = Path()
        arc.addArc(
            center: center,
            radius: ringRadius,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + 360 * clamped),
            clockwise: false
        )
        ctx.stroke(arc, with: .color(color),
                   style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
    }

    // Apple Activity ring colours (close approximations).
    public static let moveColor = Color(red: 1.000, green: 0.122, blue: 0.337)
    public static let exerciseColor = Color(red: 0.573, green: 0.902, blue: 0.165)
    public static let standColor = Color(red: 0.094, green: 0.886, blue: 1.000)
}

#Preview("Activity Rings") {
    HStack(spacing: 24) {
        ActivityRings(move: 0.84, exercise: 0.62, stand: 0.75)
            .frame(width: 100, height: 100)
        ActivityRings(move: 1.2, exercise: 1.0, stand: 1.0)
            .frame(width: 100, height: 100)
    }
    .padding()
    .background(Color.sparkSurface)
}
