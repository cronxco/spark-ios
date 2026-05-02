import MapKit
import SparkKit
import SparkUI
import SwiftUI

/// Map tab — full-screen MapKit view with a timeline scrubber overlay and a
/// bottom sheet listing the points in the visible region. Pins are
/// Spark-tinted and tap-routable to detail screens.
struct MapView: View {
    var isEmbedded: Bool = false

    @Environment(AppModel.self) private var appModel
    @State private var viewModel: MapViewModel?
    @State private var path: [DetailRoute] = []
    @State private var cameraPosition: MapCameraPosition = .region(MapViewModel.defaultRegion)

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationDestination(for: DetailRoute.self) { route in
                    switch route {
                    case .place(let id):
                        PlaceDetailView(placeId: id)
                    case .event(let id):
                        EventDetailView(eventId: id)
                    case .object(let id):
                        ObjectDetailView(objectId: id)
                    case .block(let id):
                        BlockDetailView(blockId: id)
                    case .metric(let identifier):
                        MetricDetailView(identifier: identifier)
                    case .integration(let service):
                        IntegrationDetailView(integrationId: service)
                    }
                }
                .navigationTitle("Map")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(isEmbedded ? .hidden : .visible, for: .navigationBar)
        }
        .task {
            if viewModel == nil {
                viewModel = MapViewModel(apiClient: appModel.apiClient)
                await viewModel?.fetch()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let viewModel {
            MapViewContent(viewModel: viewModel, cameraPosition: $cameraPosition) { point in
                handleSelection(point)
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func handleSelection(_ point: MapDataPoint) {
        switch point.kind {
        case .place:
            push(.place(id: point.id))
        case .transaction, .event, .workout:
            push(.event(id: point.id))
        }
    }

    private func push(_ route: DetailRoute) {
        if path.last == route { return }
        path.append(route)
    }
}

private struct MapViewContent: View {
    @Bindable var viewModel: MapViewModel
    @Binding var cameraPosition: MapCameraPosition
    let onSelectPoint: (MapDataPoint) -> Void

    @State private var sheetDetent: PresentationDetent = .height(160)

    var body: some View {
        Map(position: $cameraPosition) {
            ForEach(viewModel.visiblePoints) { point in
                Annotation(point.title, coordinate: CLLocationCoordinate2D(latitude: point.lat, longitude: point.lng)) {
                    MapPin(kind: point.kind)
                        .onTapGesture { onSelectPoint(point) }
                }
            }
        }
        .mapStyle(.standard)
        .mapControls {
            MapCompass()
            MapScaleView()
            MapUserLocationButton()
        }
        .ignoresSafeArea(edges: .bottom)
        .overlay(alignment: .bottom) {
            TimelineScrubber(
                fraction: $viewModel.dayFraction,
                anchorDay: viewModel.anchorDay
            )
            .padding(.horizontal, SparkSpacing.lg)
            .padding(.bottom, SparkSpacing.xxl + SparkSpacing.xxxl)
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            viewModel.regionDidChange(context.region)
        }
        .sheet(isPresented: .constant(true)) {
            MapBottomSheet(points: viewModel.visiblePoints, onSelect: onSelectPoint)
                .presentationDetents([.height(160), .medium, .large], selection: $sheetDetent)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled()
        }
    }
}

private struct MapPin: View {
    let kind: MapDataPoint.Kind

    var body: some View {
        ZStack {
            Circle()
                .fill(.background)
                .frame(width: 32, height: 32)
                .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
            Image(systemName: glyph)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
        }
        .accessibilityLabel(Text(accessibilityLabel))
    }

    private var glyph: String {
        switch kind {
        case .place: "mappin"
        case .transaction: "creditcard.fill"
        case .workout: "figure.run"
        case .event: "sparkles"
        }
    }

    private var tint: Color {
        switch kind {
        case .place: .sparkAccent
        case .transaction: .domainMoney
        case .workout: .domainActivity
        case .event: .domainKnowledge
        }
    }

    private var accessibilityLabel: String {
        switch kind {
        case .place: "Place"
        case .transaction: "Transaction"
        case .workout: "Workout"
        case .event: "Event"
        }
    }
}
