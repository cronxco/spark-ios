import MapKit
import SparkKit
import SparkUI
import SwiftUI

/// Explore's Map. The Day view draws one day as a journey: glyph-chip pins
/// joined by a route in time order, a glass timeline that steps between
/// days and snaps to stops, and an opaque card for the selected stop (or
/// the day, when nothing is selected). The Places view lists every saved
/// place. Content sits on opaque surfaces; only the controls are glass
/// (`docs/design-language.md` section 5.3).
struct MapView: View {
    @Binding var path: [DetailRoute]

    @Environment(AppModel.self) private var appModel
    @State private var viewModel: MapViewModel?

    var body: some View {
        Group {
            if let viewModel {
                MapViewContent(viewModel: viewModel) { route in
                    if path.last != route { path.append(route) }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            if viewModel == nil {
                let model = MapViewModel(apiClient: appModel.apiClient)
                viewModel = model
                await model.fetch()
            }
        }
    }
}

private struct MapViewContent: View {
    @Bindable var viewModel: MapViewModel
    let open: (DetailRoute) -> Void

    @State private var camera: MapCameraPosition = .automatic

    var body: some View {
        // The map runs under the tab bar; the controls and cards keep to
        // the safe area above it.
        ZStack {
            map
                .ignoresSafeArea(edges: .bottom)
            VStack(spacing: 0) {
                topControls
                Spacer(minLength: SparkSpacing.lg)
                bottomContent
            }
        }
        .onChange(of: viewModel.selectedStopID) { _, _ in focusOnSelection() }
        .onChange(of: viewModel.day) { _, _ in camera = .automatic }
        .onChange(of: viewModel.mode) { _, _ in camera = .automatic }
    }

    // MARK: - Map

    private var map: some View {
        Map(position: $camera) {
            if viewModel.clusters.isEmpty {
                switch viewModel.mode {
                case .day: dayContent
                case .places: placesContent
                }
            } else {
                clusterContent
            }
            UserAnnotation()
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            viewModel.regionDidChange(context.region)
        }
    }

    @MapContentBuilder
    private var dayContent: some MapContent {
        let stops = viewModel.stops
        let selectedTime = viewModel.timelineTime
        // The route so far is solid; the rest of the day is a faint dash.
        let past = stops.filter { ($0.stopTime ?? .distantPast) <= selectedTime }
        if past.count > 1 {
            MapPolyline(coordinates: past.map(\.coordinate))
                .stroke(Color.domainOnline, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
        }
        if let start = past.last, stops.count > past.count {
            let later = [start] + stops.dropFirst(past.count)
            MapPolyline(coordinates: later.map(\.coordinate))
                .stroke(Color.domainOnline.opacity(0.5), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round, dash: [2, 7]))
        } else if past.isEmpty, stops.count > 1 {
            MapPolyline(coordinates: stops.map(\.coordinate))
                .stroke(Color.domainOnline.opacity(0.5), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round, dash: [2, 7]))
        }

        ForEach(viewModel.pins) { pin in
            let selected = pin.stops.contains { $0.id == viewModel.selectedStopID }
            let shown = selected ? viewModel.selectedStop ?? pin.stops[0] : pin.stops[0]
            let later = pin.stops.allSatisfy { ($0.stopTime ?? .distantPast) > selectedTime }
            Annotation(pin.title, coordinate: pin.coordinate) {
                Button {
                    selectNext(in: pin)
                } label: {
                    MapPinChip(point: shown, count: pin.stops.count, isSelected: selected)
                        .opacity(later && !selected ? 0.45 : 1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(pinLabel(pin))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
            .annotationTitles(selected ? .visible : .automatic)
        }
    }

    @MapContentBuilder
    private var placesContent: some MapContent {
        ForEach(viewModel.savedPlaces) { place in
            Annotation(place.title, coordinate: place.coordinate) {
                Button {
                    open(place.detailRoute)
                } label: {
                    MapPinChip(point: place, count: 1, isSelected: false)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(place.title)
            }
            .annotationTitles(.hidden)
        }
    }

    @MapContentBuilder
    private var clusterContent: some MapContent {
        ForEach(viewModel.clusters) { cluster in
            Annotation("", coordinate: CLLocationCoordinate2D(latitude: cluster.lat, longitude: cluster.lng)) {
                Button {
                    withAnimation(.snappy) {
                        camera = .region(MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: cluster.lat, longitude: cluster.lng),
                            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                        ))
                    }
                } label: {
                    MapClusterChip(count: cluster.count)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(cluster.count.formatted()) points, zoom in")
            }
        }
    }

    // MARK: - Overlays

    private var topControls: some View {
        HStack(alignment: .top) {
            Picker("Map view", selection: $viewModel.mode) {
                ForEach(MapViewModel.Mode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 160)
            .padding(SparkSpacing.xxs)
            .sparkGlass(.capsule)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, SparkSpacing.lg)
        .padding(.top, SparkSpacing.sm)
    }

    @ViewBuilder
    private var bottomContent: some View {
        switch viewModel.mode {
        case .day:
            VStack(spacing: SparkSpacing.md) {
                dayCard
                TimelineScrubber(viewModel: viewModel)
            }
            .padding(.horizontal, SparkSpacing.lg)
            .padding(.bottom, SparkSpacing.md)
        case .places:
            MapPlacesPanel(viewModel: viewModel, open: open)
        }
    }

    @ViewBuilder
    private var dayCard: some View {
        if let stop = viewModel.selectedStop, let index = viewModel.selectedIndex {
            MapStopCard(stop: stop, position: index + 1, of: viewModel.stops.count) {
                open(stop.detailRoute)
            } onStep: { offset in
                withAnimation(.snappy) { viewModel.selectStop(offset: offset) }
            }
            .transition(.opacity)
        } else if let error = viewModel.lastError, viewModel.points.isEmpty {
            MapMessageCard(title: "Map unavailable", message: error)
        } else if viewModel.hasLoaded && viewModel.stops.isEmpty && viewModel.clusters.isEmpty {
            MapMessageCard(
                title: "Nothing on the map",
                message: "No events or places with a location on this day."
            )
        } else if !viewModel.stops.isEmpty {
            MapDaySummaryCard(stops: viewModel.stops) {
                withAnimation(.snappy) { viewModel.selectStop(offset: 1) }
            }
        }
    }

    // MARK: - Selection

    /// A tap on a pin selects its first stop, then steps through the
    /// others at the same spot (two payments at one café).
    private func selectNext(in pin: MapPinGroup) {
        withAnimation(.snappy) {
            if let current = pin.stops.firstIndex(where: { $0.id == viewModel.selectedStopID }) {
                viewModel.select(pin.stops[(current + 1) % pin.stops.count])
            } else {
                viewModel.select(pin.stops.first)
            }
        }
    }

    private func focusOnSelection() {
        guard let stop = viewModel.selectedStop else { return }
        withAnimation(.snappy) {
            camera = .camera(MapCamera(centerCoordinate: stop.coordinate, distance: 4_000))
        }
    }

    private func pinLabel(_ pin: MapPinGroup) -> String {
        let times = pin.stops.compactMap(\.stopTime).map { Self.timeFormatter.string(from: $0) }
        let kind = pin.stops.count == 1 ? pin.stops[0].mapLabel : "\(pin.stops.count) stops"
        return ([pin.title, kind] + times).joined(separator: ", ")
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "HH:mm"
        return f
    }()
}

extension MapDataPoint {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

// MARK: - Pins

/// A pin is a glyph chip (section 6): the glyph in its tint on a 14% wash,
/// a rounded square with a ring in the surface colour so it lifts off the
/// map without a shadow. Selected, it fills solid, like a selected domain
/// chip, and grows. More than one stop at a spot shows a count.
private struct MapPinChip: View {
    let point: MapDataPoint
    let count: Int
    let isSelected: Bool

    var body: some View {
        let size: CGFloat = isSelected ? 44 : 34
        let shape = RoundedRectangle(cornerRadius: isSelected ? 11 : 9, style: .continuous)
        SparkGlyph(point.mapIcon, size: isSelected ? 18 : 14, relativeTo: .caption)
            .foregroundStyle(isSelected ? Color.sparkOnAccent : point.mapTint)
            .frame(width: size, height: size)
            .background {
                if isSelected {
                    shape.fill(point.mapTint)
                } else {
                    shape.fill(Color.sparkElevated).overlay(shape.fill(point.mapTint.opacity(0.14)))
                }
            }
            .overlay(shape.strokeBorder(Color.sparkElevated, lineWidth: 2))
            .overlay(alignment: .topTrailing) {
                if count > 1 {
                    Text("\(count)")
                        .font(SparkTypography.captionStrong)
                        .monospacedDigit()
                        .foregroundStyle(Color.sparkElevated)
                        .padding(.horizontal, SparkSpacing.xs)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Color.primary, in: .capsule)
                        .offset(x: 8, y: -8)
                }
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(.rect)
            .animation(.snappy, value: isSelected)
    }
}

private struct MapClusterChip: View {
    let count: Int

    var body: some View {
        HStack(spacing: SparkSpacing.xs) {
            DomainGlyph(.place, tint: .domainOnline, size: 24)
            Text(count.formatted())
                .font(SparkTypography.bodyStrong)
                .monospacedDigit()
        }
        .padding(.leading, SparkSpacing.xs)
        .padding(.trailing, SparkSpacing.md)
        .frame(minHeight: 36)
        .sparkContentSurface(radius: SparkRadii.md)
        .overlay(RoundedRectangle(cornerRadius: SparkRadii.md, style: .continuous).strokeBorder(Color.sparkElevated, lineWidth: 2))
    }
}

// MARK: - Cards

/// The selected stop, on an opaque content surface. A tap opens its event
/// or place; a horizontal swipe moves to the next or previous stop.
private struct MapStopCard: View {
    let stop: MapDataPoint
    let position: Int
    let of: Int
    let onOpen: () -> Void
    let onStep: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.xs + 2) {
            HStack(spacing: SparkSpacing.xs + 2) {
                SparkGlyph(stop.mapIcon, size: 13, relativeTo: .caption)
                    .foregroundStyle(stop.mapTint)
                Text(stop.mapLabel)
                    .font(SparkTypography.captionStrong)
                    .foregroundStyle(.secondary)
                Spacer(minLength: SparkSpacing.sm)
                if let time = stop.stopTime {
                    SparkTimeText(time)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: SparkSpacing.md) {
                Text(stop.title)
                    .font(SparkTypography.bodyStrong)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let value = stop.subtitle, !value.isEmpty, stop.kind != .place {
                    Text(value)
                        .font(SparkTypography.bodyStrong)
                        .monospacedDigit()
                        .foregroundStyle(stop.mapHero)
                        .lineLimit(1)
                }
            }
            HStack(spacing: SparkSpacing.md) {
                Text(stop.mapContext ?? "")
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("\(position) of \(of)")
                    .monospacedDigit()
            }
            .font(SparkTypography.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, SparkSpacing.md + 2)
        .padding(.horizontal, SparkSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sparkContentSurface()
        .onTapGesture(perform: onOpen)
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    onStep(value.translation.width < 0 ? 1 : -1)
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens the \(stop.mapLabel.lowercased())")
        .accessibilityAction(named: "Next stop") { onStep(1) }
        .accessibilityAction(named: "Previous stop") { onStep(-1) }
    }
}

/// The day at a glance when no stop is selected: counts in a stat grid.
private struct MapDaySummaryCard: View {
    let stops: [MapDataPoint]
    let onStart: () -> Void

    var body: some View {
        let payments = stops.filter { $0.kind == .transaction }.count
        let places = stops.filter { $0.kind == .place }.count
        Button(action: onStart) {
            VStack(alignment: .leading, spacing: SparkSpacing.sm + 2) {
                HStack(spacing: SparkSpacing.xs + 2) {
                    SparkGlyph(.distance, size: 13, relativeTo: .caption)
                    Text("The day")
                        .font(SparkTypography.captionStrong)
                }
                .foregroundStyle(.secondary)
                HStack(spacing: SparkSpacing.sm) {
                    stat(stops.count, "Stops", tint: .primary)
                    stat(payments, "Payments", tint: .sparkHero(domain: "money"))
                    stat(places, "Places", tint: .primary)
                }
            }
            .padding(.vertical, SparkSpacing.md + 2)
            .padding(.horizontal, SparkSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sparkContentSurface()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows the first stop")
    }

    private func stat(_ value: Int, _ label: String, tint: Color) -> some View {
        VStack(spacing: SparkSpacing.xxs) {
            Text(value.formatted())
                .font(SparkTypography.compactValue)
                .monospacedDigit()
                .foregroundStyle(tint)
            Text(label)
                .font(SparkTypography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct MapMessageCard: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: SparkSpacing.xs) {
            SparkGlyph(.place, size: 20)
                .foregroundStyle(.secondary)
            Text(title)
                .font(SparkTypography.bodyStrong)
            Text(message)
                .font(SparkTypography.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(SparkSpacing.lg)
        .frame(maxWidth: .infinity)
        .sparkContentSurface()
    }
}
