import SparkKit
import SparkUI
import SwiftUI

/// The Places view: every saved place on a content surface that rises over
/// the lower half of the map, with search and a sort menu. Rows are `row`
/// size (section 7.2): glyph chip, title, address, visits and the last
/// visit. A tap opens the place.
struct MapPlacesPanel: View {
    @Bindable var viewModel: MapViewModel
    let open: (DetailRoute) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            header
            search
            list
        }
        .padding(.top, SparkSpacing.lg)
        .padding(.horizontal, SparkSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .top)
        .containerRelativeFrame(.vertical, alignment: .top) { length, _ in length * 0.55 }
        .sparkContentSurface(radius: SparkRadii.lg)
        .padding(.horizontal, SparkSpacing.sm)
        .padding(.bottom, SparkSpacing.sm)
    }

    private var header: some View {
        HStack {
            Text("Places (\(viewModel.placeCount.formatted()))")
                .font(SparkTypography.title)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: SparkSpacing.sm)
            Menu {
                Picker("Sort", selection: $viewModel.placeSort) {
                    ForEach(MapViewModel.PlaceSort.allCases, id: \.self) { sort in
                        Text(sort.label).tag(sort)
                    }
                }
            } label: {
                HStack(spacing: SparkSpacing.xs + 2) {
                    Text(viewModel.placeSort.label)
                    SparkGlyph(.expand, size: 10, relativeTo: .caption)
                }
                .font(SparkTypography.bodySmall)
                .padding(.horizontal, SparkSpacing.md)
                .frame(minHeight: 32)
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.12)))
            }
            .accessibilityLabel("Sort places")
            .accessibilityValue(viewModel.placeSort.label)
        }
    }

    private var search: some View {
        HStack(spacing: SparkSpacing.sm) {
            SparkGlyph(.search, size: 14)
                .foregroundStyle(.secondary)
            TextField("Search places", text: $viewModel.placeSearch)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
        }
        .padding(.horizontal, SparkSpacing.md)
        .frame(minHeight: 36)
        .background(Color.sparkSurface, in: .rect(cornerRadius: SparkRadii.sm + 2))
    }

    @ViewBuilder
    private var list: some View {
        let places = viewModel.savedPlaces
        if places.isEmpty {
            VStack(spacing: SparkSpacing.sm) {
                SparkGlyph(.place, size: 28, relativeTo: .largeTitle)
                    .foregroundStyle(.secondary)
                Text(viewModel.placeSearch.isEmpty ? "No places yet" : "No matching places")
                    .font(SparkTypography.bodyStrong)
                Text(viewModel.placeSearch.isEmpty
                    ? "Places appear here once Spark spots you visiting them."
                    : "Try a different search.")
                    .font(SparkTypography.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(places) { place in
                        Button {
                            open(place.detailRoute)
                        } label: {
                            MapPlaceRow(place: place)
                        }
                        .buttonStyle(.plain)
                        if place.id != places.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.bottom, SparkSpacing.lg)
            }
            .scrollIndicators(.hidden)
        }
    }
}

private struct MapPlaceRow: View {
    let place: MapDataPoint

    var body: some View {
        HStack(spacing: SparkSpacing.md) {
            DomainGlyph(.place, tint: place.mapTint)
            VStack(alignment: .leading, spacing: SparkSpacing.xxs) {
                Text(place.title)
                    .font(SparkTypography.bodyStrong)
                    .lineLimit(1)
                if let detail {
                    Text(detail)
                        .font(SparkTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: SparkSpacing.xxs) {
                if let visits = place.visitCount {
                    Text(visits == 1 ? "1 visit" : "\(visits.formatted()) visits")
                        .font(SparkTypography.bodyStrong)
                        .monospacedDigit()
                }
                if let last = place.lastVisitAt {
                    SparkTimeText(last)
                }
            }
        }
        .padding(.vertical, SparkSpacing.sm + 2)
        .frame(minHeight: 60)
        .contentShape(.rect)
    }

    /// The address, without repeating the title it often starts with.
    private var detail: String? {
        guard let address = place.address, !address.isEmpty else { return place.category?.capitalized }
        if address.hasPrefix(place.title) {
            let rest = address.dropFirst(place.title.count).trimmingCharacters(in: CharacterSet(charactersIn: ", "))
            return rest.isEmpty ? nil : rest
        }
        return address
    }
}
