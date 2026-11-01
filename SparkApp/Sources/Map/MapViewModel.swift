import Foundation
import MapKit
import Observation
import OSLog
import SparkKit

/// Drives Explore's Map. The Day view shows one day as a journey: the
/// day's located events and the places last visited that day, in time
/// order. The Places view lists every saved place. Both come from one
/// `/map/data` request for the day, because places are not date-filtered.
@MainActor
@Observable
final class MapViewModel {
    enum Mode: String, CaseIterable, Hashable {
        case day, places

        var label: String {
            switch self {
            case .day: "Day"
            case .places: "Places"
            }
        }
    }

    enum PlaceSort: String, CaseIterable, Hashable {
        case visits, recent, name

        var label: String {
            switch self {
            case .visits: "Most visited"
            case .recent: "Recent"
            case .name: "Name"
            }
        }
    }

    private let apiClient: APIClient
    private let calendar: Calendar
    private let logger = Logger(subsystem: "co.cronx.sparkapp", category: "MapViewModel")

    var mode: Mode = .day
    private(set) var day: Date
    /// The stop the card and the timeline point at. Nil shows the day.
    var selectedStopID: String?

    var placeSearch = ""
    var placeSort: PlaceSort = .visits

    private(set) var points: [MapDataPoint] = []
    private(set) var clusters: [MapCluster] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var lastError: String?

    /// Above 500 points the backend sends clusters, so the map falls back
    /// to asking for the region in view.
    private var region: MKCoordinateRegion?
    private var pendingFetch: Task<Void, Never>?

    init(apiClient: APIClient, calendar: Calendar = .current, now: Date = .now) {
        self.apiClient = apiClient
        self.calendar = calendar
        self.day = calendar.startOfDay(for: now)
    }

    // MARK: - Derived

    /// The day's stops in time order: located events, and places whose most
    /// recent visit falls on the day.
    var stops: [MapDataPoint] {
        Self.stops(from: points, on: day, calendar: calendar)
    }

    /// Stops grouped by where they happened, so two payments at one café
    /// share a pin.
    var pins: [MapPinGroup] {
        MapPinGroup.group(stops)
    }

    var selectedStop: MapDataPoint? {
        guard let selectedStopID else { return nil }
        return stops.first { $0.id == selectedStopID }
    }

    var selectedIndex: Int? {
        guard let selectedStopID else { return nil }
        return stops.firstIndex { $0.id == selectedStopID }
    }

    /// The moment the timeline points at: the selected stop, or the end of
    /// the day (now, for today) when nothing is selected.
    var timelineTime: Date {
        if let time = selectedStop?.stopTime { return time }
        let end = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        return min(end, .now)
    }

    var isToday: Bool { calendar.isDateInToday(day) }

    var savedPlaces: [MapDataPoint] {
        let places = points.filter { $0.kind == .place }
        let query = placeSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        let matching = query.isEmpty ? places : places.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || ($0.address?.localizedCaseInsensitiveContains(query) ?? false)
        }
        return Self.sorted(matching, by: placeSort)
    }

    var placeCount: Int { points.filter { $0.kind == .place }.count }

    // MARK: - Intents

    func select(_ stop: MapDataPoint?) {
        selectedStopID = stop?.id
    }

    func selectStop(offset: Int) {
        let stops = stops
        guard !stops.isEmpty else { return }
        guard let index = selectedIndex else {
            selectedStopID = offset >= 0 ? stops.first?.id : stops.last?.id
            return
        }
        let next = index + offset
        guard stops.indices.contains(next) else { return }
        selectedStopID = stops[next].id
    }

    /// The stop nearest a moment on the timeline, for a drag that snaps.
    func selectStop(nearest time: Date) {
        selectedStopID = stops.min {
            abs(($0.stopTime ?? day).timeIntervalSince(time)) < abs(($1.stopTime ?? day).timeIntervalSince(time))
        }?.id
    }

    func showDay(offset: Int) {
        guard let next = calendar.date(byAdding: .day, value: offset, to: day) else { return }
        showDay(next)
    }

    func showDay(_ date: Date) {
        let start = calendar.startOfDay(for: date)
        guard start <= calendar.startOfDay(for: .now), start != day else { return }
        day = start
        selectedStopID = nil
        scheduleFetch(debounce: false)
    }

    func regionDidChange(_ new: MKCoordinateRegion) {
        region = new
        // The day's stops come back whole; only a clustered answer depends
        // on the region in view.
        if !clusters.isEmpty { scheduleFetch(debounce: true) }
    }

    // MARK: - Loading

    private func scheduleFetch(debounce: Bool) {
        pendingFetch?.cancel()
        pendingFetch = Task { [weak self] in
            if debounce {
                try? await Task.sleep(for: .milliseconds(250))
            }
            guard !Task.isCancelled else { return }
            await self?.fetch()
        }
    }

    func fetch() async {
        isLoading = true
        defer {
            isLoading = false
            hasLoaded = true
        }
        let requestedDay = day
        do {
            var response = try await apiClient.request(MapEndpoint.points(bbox: .world, date: requestedDay))
            if !response.clusters.isEmpty, let region {
                response = try await apiClient.request(
                    MapEndpoint.points(bbox: Self.boundingBox(for: region), date: requestedDay)
                )
            }
            guard requestedDay == day else { return }
            points = response.allPoints
            clusters = response.clusters
            if let selectedStopID, !stops.contains(where: { $0.id == selectedStopID }) {
                self.selectedStopID = nil
            }
            lastError = nil
        } catch is CancellationError {
            return
        } catch APIError.notModified {
            // Cached payload is fine; keep current points.
        } catch {
            SparkObservability.captureHandled(error)
            logger.error("Map fetch failed: \(String(describing: error))")
            lastError = "Couldn’t load the map."
        }
    }

    // MARK: - Pure helpers (tested)

    nonisolated static func stops(from points: [MapDataPoint], on day: Date, calendar: Calendar) -> [MapDataPoint] {
        points
            .filter { point in
                guard let time = point.stopTime else { return false }
                return calendar.isDate(time, inSameDayAs: day)
            }
            .sorted { ($0.stopTime ?? .distantPast, $0.id) < ($1.stopTime ?? .distantPast, $1.id) }
    }

    nonisolated static func sorted(_ places: [MapDataPoint], by sort: PlaceSort) -> [MapDataPoint] {
        switch sort {
        case .visits:
            places.sorted {
                let lhs = $0.visitCount ?? 0, rhs = $1.visitCount ?? 0
                if lhs != rhs { return lhs > rhs }
                return ($0.lastVisitAt ?? .distantPast) > ($1.lastVisitAt ?? .distantPast)
            }
        case .recent:
            places.sorted { ($0.lastVisitAt ?? .distantPast) > ($1.lastVisitAt ?? .distantPast) }
        case .name:
            places.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        }
    }

    nonisolated static func boundingBox(for region: MKCoordinateRegion) -> BoundingBox {
        let half = (lat: region.span.latitudeDelta / 2, lng: region.span.longitudeDelta / 2)
        return BoundingBox(
            southWest: .init(lat: max(-90, region.center.latitude - half.lat), lng: max(-180, region.center.longitude - half.lng)),
            northEast: .init(lat: min(90, region.center.latitude + half.lat), lng: min(180, region.center.longitude + half.lng))
        )
    }
}

/// One pin: every stop at the same spot, to about 10 m.
struct MapPinGroup: Identifiable, Hashable {
    let id: String
    let lat: Double
    let lng: Double
    let stops: [MapDataPoint]

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    var title: String { stops.first?.title ?? "" }

    static func group(_ stops: [MapDataPoint]) -> [MapPinGroup] {
        var order: [String] = []
        var groups: [String: [MapDataPoint]] = [:]
        for stop in stops {
            let key = String(format: "%.4f,%.4f", stop.lat, stop.lng)
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(stop)
        }
        return order.compactMap { key in
            guard let members = groups[key], let first = members.first else { return nil }
            return MapPinGroup(id: key, lat: first.lat, lng: first.lng, stops: members)
        }
    }
}
