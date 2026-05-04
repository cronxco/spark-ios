import CoreLocation
import SparkUI
import SwiftUI

struct LocationStep: View {
    let proceed: () -> Void

    @State private var manager = CLLocationManager()
    @State private var status: CLAuthorizationStatus = .notDetermined

    var body: some View {
        SparkOnboardingScaffold(
            icon: "location.fill",
            title: "Know your places",
            bodyText: "Spark uses your location to tag check-ins and detect visits to places that matter to you."
        ) {
            EmptyView()
        } actions: {
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.sparkSuccess)
                    Text("Location access granted")
                        .font(SparkTypography.body)
                }
                PillButton("Continue", systemImage: "arrow.right.circle.fill", action: proceed)
            } else {
                PillButton("Allow location", systemImage: "location.fill") {
                    manager.requestWhenInUseAuthorization()
                }
                Button("Skip for now") { proceed() }
                    .font(SparkTypography.bodySmall)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { status = manager.authorizationStatus }
        .onChange(of: manager.authorizationStatus) { _, new in
            status = new
            if new == .authorizedWhenInUse || new == .authorizedAlways { proceed() }
        }
    }
}
