import CoreLocation
import SparkUI
import SwiftUI

// MARK: - Location state

enum LocationState {
    case idle
    case fetching
    case resolved(address: String?, lat: Double, lng: Double)
    case failed(String)
    case denied
}

// MARK: - Location chip

struct LocationChip: View {
    let state: LocationState
    let onTap: () -> Void
    let onClear: () -> Void

    var body: some View {
        switch state {
        case .idle:
            Button(action: onTap) {
                Label("Add location", systemImage: "location")
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, SparkSpacing.md)
                    .padding(.vertical, SparkSpacing.sm)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(.capsule)
                    .overlay(Capsule().strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1, antialiased: true))
            }
            .buttonStyle(.plain)

        case .fetching:
            HStack(spacing: SparkSpacing.sm) {
                ProgressView().scaleEffect(0.7)
                Text("Getting location…")
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.secondary)
            }

        case let .resolved(address, _, _):
            HStack(spacing: SparkSpacing.xs) {
                Image(systemName: "location.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.sparkAccent)
                Text(address ?? "Current location")
                    .font(SparkTypography.monoSmall)
                    .lineLimit(1)
                Button(action: onClear) {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove location")
            }
            .padding(.horizontal, SparkSpacing.md)
            .padding(.vertical, SparkSpacing.sm)
            .background(Color.sparkAccent.opacity(0.08))
            .clipShape(.capsule)

        case let .failed(message):
            Button(action: onTap) {
                Text(message + " — retry")
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(Color.sparkWarning)
            }
            .buttonStyle(.plain)

        case .denied:
            Text("Location access denied")
                .font(SparkTypography.monoSmall)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Shared location fetch helper

@MainActor
func fetchLocationState(current: LocationState) async -> LocationState {
    let status = CLLocationManager().authorizationStatus
    switch status {
    case .denied, .restricted:
        return .denied
    default:
        break
    }
    do {
        for try await update in CLLocationUpdate.liveUpdates() {
            guard let location = update.location,
                  location.horizontalAccuracy >= 0,
                  location.horizontalAccuracy < 200 else { continue }
            return .resolved(
                address: nil,
                lat: location.coordinate.latitude,
                lng: location.coordinate.longitude
            )
        }
    } catch {
        let newStatus = CLLocationManager().authorizationStatus
        if newStatus == .denied || newStatus == .restricted {
            return .denied
        } else {
            return .failed("Couldn't get location")
        }
    }
    return current
}
