import MapKit
import SparkKit
import SparkUI
import SwiftUI

/// Read-only map of a workout's GPS route. Shown only for events whose detail
/// has `hasRoute`; loads the points itself so the detail payload stays light.
struct EventRouteSection: View {
    let eventID: String
    let apiClient: APIClient

    @State private var route: EventRoute?
    @State private var isLoading = true
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
            SparkDetailSectionHeader("Route", trailing: route.flatMap(Self.summary(for:)))

            if let route, route.isDrawable, let bounds = route.bounds {
                map(for: route, bounds: bounds)
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else if failed {
                Button { Task { await load() } } label: {
                    Label("Couldn't load the route. Tap to retry.", systemImage: "arrow.clockwise")
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            } else {
                Text("Not enough GPS points to draw this route.")
                    .font(SparkTypography.bodySmall)
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: eventID) { await load() }
    }

    private func map(for route: EventRoute, bounds: EventRoute.Bounds) -> some View {
        let coordinates = route.points.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
        let span = bounds.span()
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: bounds.centerLat, longitude: bounds.centerLng),
            span: MKCoordinateSpan(latitudeDelta: span.lat, longitudeDelta: span.lng)
        )

        // `isDrawable` guarantees at least two points, so both ends exist.
        return Map(initialPosition: .region(region), interactionModes: []) {
            MapPolyline(coordinates: coordinates)
                .stroke(Color.sparkAccent, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            Marker("Start", systemImage: "figure.run", coordinate: coordinates[0])
                .tint(.green)
            Marker("Finish", systemImage: "flag.checkered", coordinate: coordinates[coordinates.count - 1])
                .tint(.red)
        }
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: SparkRadii.lg))
        .overlay {
            RoundedRectangle(cornerRadius: SparkRadii.lg)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.summary(for: route).map { "Workout route map, \($0)" } ?? "Workout route map")
    }

    private func load() async {
        isLoading = true
        failed = false
        defer { isLoading = false }
        do {
            route = try await apiClient.request(EventsEndpoint.route(id: eventID))
        } catch {
            SparkObservability.captureHandled(error)
            failed = true
        }
    }

    /// "5.02 km · 25 min", from whatever the source recorded.
    private static func summary(for route: EventRoute) -> String? {
        var parts: [String] = []
        if let distance = route.distance {
            let value = distance.formatted(.number.precision(.fractionLength(2)))
            parts.append("\(value) \(route.distanceUnit ?? "km")")
        }
        if let seconds = route.durationSeconds, seconds > 0 {
            let duration = Duration.seconds(seconds)
            parts.append(duration.formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
