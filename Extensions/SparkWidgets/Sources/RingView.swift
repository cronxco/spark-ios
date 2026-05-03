import SwiftUI

/// Circular progress ring reused across all widget families.
struct RingView: View {
    let progress: Double
    let lineWidth: CGFloat
    let gradient: AngularGradient
    var backgroundColor: Color = Color.secondary.opacity(0.2)

    var body: some View {
        ZStack {
            Circle()
                .stroke(backgroundColor, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

extension RingView {
    static func sleep(progress: Double, size: CGFloat = 48) -> some View {
        RingView(
            progress: progress,
            lineWidth: size * 0.12,
            gradient: AngularGradient(
                colors: [.indigo, .purple, .indigo],
                center: .center,
                startAngle: .degrees(-90),
                endAngle: .degrees(270)
            )
        )
        .frame(width: size, height: size)
    }

    static func steps(progress: Double, size: CGFloat = 48) -> some View {
        RingView(
            progress: progress,
            lineWidth: size * 0.12,
            gradient: AngularGradient(
                colors: [.green, .mint, .green],
                center: .center,
                startAngle: .degrees(-90),
                endAngle: .degrees(270)
            )
        )
        .frame(width: size, height: size)
    }

    static func move(progress: Double, size: CGFloat = 40) -> some View {
        RingView(
            progress: progress,
            lineWidth: size * 0.14,
            gradient: AngularGradient(
                colors: [.red, .orange, .red],
                center: .center,
                startAngle: .degrees(-90),
                endAngle: .degrees(270)
            )
        )
        .frame(width: size, height: size)
    }

    static func exercise(progress: Double, size: CGFloat = 30) -> some View {
        RingView(
            progress: progress,
            lineWidth: size * 0.14,
            gradient: AngularGradient(
                colors: [.green, .mint, .green],
                center: .center,
                startAngle: .degrees(-90),
                endAngle: .degrees(270)
            )
        )
        .frame(width: size, height: size)
    }

    static func stand(progress: Double, size: CGFloat = 20) -> some View {
        RingView(
            progress: progress,
            lineWidth: size * 0.14,
            gradient: AngularGradient(
                colors: [.cyan, .blue, .cyan],
                center: .center,
                startAngle: .degrees(-90),
                endAngle: .degrees(270)
            )
        )
        .frame(width: size, height: size)
    }
}
