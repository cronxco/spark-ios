import SparkUI
import SwiftUI

/// HealthKit permission scopes view. Populated fully on D14.
struct HealthKitScopesView: View {
    var body: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Health & Activity")
            .navigationBarTitleDisplayMode(.inline)
    }
}
