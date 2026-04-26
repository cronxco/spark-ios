import MapKit
import Observation
import SparkKit
import SparkUI
import SwiftUI

@MainActor
@Observable
final class PlaceDetailViewModel {
    let placeId: String
    private(set) var state: DetailLoadState<PlaceDetail> = .loading

    private let apiClient: APIClient

    init(placeId: String, apiClient: APIClient) {
        self.placeId = placeId
        self.apiClient = apiClient
    }

    func load() async {
        state = .loading
        do {
            let detail = try await apiClient.request(PlacesEndpoint.detail(id: placeId))
            state = .loaded(detail)
        } catch APIError.notModified {
            return
        } catch {
            let msg = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            state = .error(msg)
        }
    }
}

struct PlaceDetailView: View {
    let placeId: String
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: PlaceDetailViewModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SparkSpacing.lg) {
                switch viewModel?.state {
                case .loaded(let detail):
                    content(for: detail)
                case .error(let msg):
                    EmptyState(
                        systemImage: "exclamationmark.triangle.fill",
                        title: "Couldn't load place",
                        message: msg,
                        actionTitle: "Retry"
                    ) { Task { await viewModel?.load() } }
                default:
                    LoadingShimmerCard()
                    LoadingShimmerCard()
                }
            }
            .padding(SparkSpacing.lg)
        }
        .background(Color.sparkSurface.ignoresSafeArea())
        .navigationTitle("Place")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: placeId) {
            if viewModel == nil {
                viewModel = PlaceDetailViewModel(placeId: placeId, apiClient: appModel.apiClient)
            }
            await viewModel?.load()
        }
    }

    @ViewBuilder
    private func content(for detail: PlaceDetail) -> some View {
        heroCard(for: detail)
        if let region = mapRegion(for: detail.place) {
            mapCard(region: region, place: detail.place)
        }
        inspectorRows(for: detail)
        if !detail.events.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                SectionLabel("Events here (\(detail.events.count))")
                ForEach(detail.events) { event in
                    eventRow(event)
                }
            }
        }
        if !detail.nearby.isEmpty {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                SectionLabel("Nearby")
                TagChipRow(detail.nearby.map(\.title))
            }
        }
    }

    // MARK: - Hero

    private func heroCard(for detail: PlaceDetail) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: SparkSpacing.sm) {
                HStack(spacing: SparkSpacing.sm) {
                    DomainGlyph(icon: "mappin.and.ellipse", tint: .sparkAccent, size: 28)
                    if let category = detail.place.category {
                        Text(category.uppercased())
                            .font(SparkTypography.monoSmall)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    if let streak = detail.streakDays, streak > 0 {
                        Text("\(streak)d streak")
                            .font(SparkTypography.monoSmall)
                            .foregroundStyle(Color.sparkAccent)
                            .padding(.horizontal, SparkSpacing.sm)
                            .padding(.vertical, SparkSpacing.xxs)
                            .background(.thinMaterial, in: Capsule())
                    }
                }

                Text(detail.place.title)
                    .font(SparkFonts.display(.title2, weight: .bold))
                    .accessibilityAddTraits(.isHeader)

                if let address = detail.place.address {
                    Text(address)
                        .font(SparkTypography.bodySmall)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Map

    private func mapCard(region: MKCoordinateRegion, place: Place) -> some View {
        let coord = CLLocationCoordinate2D(
            latitude: place.latitude ?? region.center.latitude,
            longitude: place.longitude ?? region.center.longitude
        )
        return Map(initialPosition: .region(region), interactionModes: []) {
            Annotation(place.title, coordinate: coord) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.sparkAccent)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
            }
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: SparkRadii.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SparkRadii.lg, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
        .accessibilityLabel("Map showing \(place.title)")
    }

    private func mapRegion(for place: Place) -> MKCoordinateRegion? {
        guard let lat = place.latitude, let lng = place.longitude else { return nil }
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )
    }

    // MARK: - Ledger

    private func inspectorRows(for detail: PlaceDetail) -> some View {
        GlassCard(radius: SparkRadii.md, padding: 0) {
            VStack(spacing: 0) {
                InspectorRow("Visits", "\(detail.visitCount)")
                if let type = detail.place.type {
                    InspectorRow("Type", type)
                }
                if let last = detail.lastVisitedAt {
                    InspectorRow("Last", isMono: true) {
                        Text(Self.fullTimeFormatter.string(from: last))
                    }
                }
                if let lat = detail.place.latitude, let lng = detail.place.longitude {
                    InspectorRow("Coords", isMono: true) {
                        Text("\(format(lat)), \(format(lng))")
                    }
                }
            }
        }
    }

    private func eventRow(_ event: Event) -> some View {
        GlassCard(radius: SparkRadii.md, padding: SparkSpacing.md) {
            HStack(spacing: SparkSpacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.action)
                        .font(SparkTypography.bodySmall)
                    if let time = event.time {
                        Text(Self.shortTimeFormatter.string(from: time))
                            .font(SparkTypography.monoSmall)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                if let value = event.value {
                    Text(value)
                        .font(SparkTypography.bodyStrong)
                        .foregroundStyle(Color.domainTint(for: event.domain))
                }
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func format(_ coord: Double) -> String {
        String(format: "%.4f", coord)
    }

    private static let shortTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM, HH:mm"
        return f
    }()

    private static let fullTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd  HH:mm"
        return f
    }()
}
