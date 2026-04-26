import CoreLocation
import SparkUI
import SwiftUI

struct LocationStep: View {
    let proceed: () -> Void

    @State private var manager = CLLocationManager()
    @State private var status: CLAuthorizationStatus = .notDetermined

    var body: some View {
        ScrollView {
            VStack(spacing: SparkSpacing.xl) {
                Spacer().frame(height: SparkSpacing.xl)

                Image(systemName: "location.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(Color.sparkAccent)

                VStack(spacing: SparkSpacing.sm) {
                    Text("Know your places")
                        .font(SparkFonts.display(.title, weight: .bold))
                    Text("Spark uses your location to tag check-ins and detect visits to places that matter to you.")
                        .font(SparkTypography.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: SparkSpacing.md) {
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
                .padding(.bottom, SparkSpacing.xxl)
            }
            .padding(.horizontal, SparkSpacing.xl)
        }
        .scrollContentBackground(.hidden)
        .background(Color.sparkSurface.ignoresSafeArea())
        .onAppear { status = manager.authorizationStatus }
        .onChange(of: manager.authorizationStatus) { _, new in
            status = new
            if new == .authorizedWhenInUse || new == .authorizedAlways { proceed() }
        }
    }
}
